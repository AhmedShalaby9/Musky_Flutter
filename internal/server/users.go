package server

import (
	"github.com/gin-gonic/gin"
	"musky/backend/internal/model"
	"strings"
)

func (a *API) listUsers(c *gin.Context) {
	limit, offset, ok := pagination(c)
	if !ok {
		return
	}
	rows, err := a.db.QueryContext(c.Request.Context(), "SELECT "+userColumns+" FROM users WHERE tenant_id=? ORDER BY id LIMIT ? OFFSET ?", tenantID(c), limit, offset)
	if err != nil {
		databaseError(c, err)
		return
	}
	defer rows.Close()
	data := []model.User{}
	for rows.Next() {
		u, err := scanUser(rows)
		if err != nil {
			databaseError(c, err)
			return
		}
		data = append(data, u)
	}
	if err = rows.Err(); err != nil {
		databaseError(c, err)
		return
	}
	c.JSON(200, gin.H{"data": data, "limit": limit, "offset": offset})
}
func (a *API) getUser(c *gin.Context) {
	id, ok := pathID(c, "id")
	if !ok {
		return
	}
	u, err := scanUser(a.db.QueryRowContext(c.Request.Context(), "SELECT "+userColumns+" FROM users WHERE tenant_id=? AND id=?", tenantID(c), id))
	if err != nil {
		databaseError(c, err)
		return
	}
	c.JSON(200, u)
}
func (a *API) createUser(c *gin.Context) {
	var in createUserInput
	if !decode(c, &in) {
		return
	}
	if !in.validate() {
		fail(c, 400, "valid name, email, admin/trader role and 12-72 byte password required")
		return
	}
	if actor(c).Role == model.Admin && in.Role != model.Trader {
		fail(c, 403, "only super_admin can create admins")
		return
	}
	hash, err := HashPassword(in.Password)
	if err != nil {
		fail(c, 500, "internal server error")
		return
	}
	result, err := a.db.ExecContext(c.Request.Context(), "INSERT INTO users(tenant_id,name,email,password_hash,role) VALUES (?,?,?,?,?)", tenantID(c), in.Name, in.Email, hash, in.Role)
	if err != nil {
		databaseError(c, err)
		return
	}
	id, err := result.LastInsertId()
	if err != nil {
		databaseError(c, err)
		return
	}
	u, err := scanUser(a.db.QueryRowContext(c.Request.Context(), "SELECT "+userColumns+" FROM users WHERE tenant_id=? AND id=?", tenantID(c), id))
	if err != nil {
		databaseError(c, err)
		return
	}
	c.JSON(201, u)
}

type updateUserInput struct {
	Name     *string     `json:"name"`
	Email    *string     `json:"email"`
	Role     *model.Role `json:"role"`
	Active   *bool       `json:"active"`
	Password *string     `json:"password"`
}

func (a *API) updateUser(c *gin.Context) {
	var in updateUserInput
	if !decode(c, &in) {
		return
	}
	if in.Name == nil && in.Email == nil && in.Role == nil && in.Active == nil && in.Password == nil {
		fail(c, 400, "no changes provided")
		return
	}
	a.saveUser(c, in, false)
}
func (a *API) deactivateUser(c *gin.Context) {
	active := false
	a.saveUser(c, updateUserInput{Active: &active}, true)
}
func (a *API) saveUser(c *gin.Context, in updateUserInput, deleted bool) {
	id, ok := pathID(c, "id")
	if !ok {
		return
	}
	if in.Name != nil {
		*in.Name = strings.TrimSpace(*in.Name)
		if !validText(*in.Name, 1, 150) {
			fail(c, 400, "invalid name")
			return
		}
	}
	if in.Email != nil {
		*in.Email = normalizeEmail(*in.Email)
		if !validEmail(*in.Email) {
			fail(c, 400, "invalid email")
			return
		}
	}
	if in.Role != nil && *in.Role != model.Admin && *in.Role != model.Trader {
		fail(c, 400, "role must be admin or trader")
		return
	}
	var hash string
	if in.Password != nil {
		var err error
		hash, err = HashPassword(*in.Password)
		if err != nil {
			fail(c, 400, err.Error())
			return
		}
	}
	tx, err := a.db.BeginTx(c.Request.Context(), nil)
	if err != nil {
		databaseError(c, err)
		return
	}
	defer tx.Rollback()
	// Serialize role/deactivation changes within a business to preserve an active admin.
	var tenant uint64
	if err = tx.QueryRowContext(c.Request.Context(), "SELECT id FROM tenants WHERE id=? FOR UPDATE", tenantID(c)).Scan(&tenant); err != nil {
		databaseError(c, err)
		return
	}
	u, err := scanUser(tx.QueryRowContext(c.Request.Context(), "SELECT "+userColumns+" FROM users WHERE tenant_id=? AND id=? FOR UPDATE", tenant, id))
	if err != nil {
		databaseError(c, err)
		return
	}
	if actor(c).Role == model.Admin && (u.Role != model.Trader || (in.Role != nil && *in.Role != model.Trader)) {
		fail(c, 403, "only super_admin can manage admins")
		return
	}
	wasAdmin := u.Role == model.Admin && u.Active
	if in.Name != nil {
		u.Name = *in.Name
	}
	if in.Email != nil {
		u.Email = *in.Email
	}
	if in.Role != nil {
		u.Role = *in.Role
	}
	if in.Active != nil {
		u.Active = *in.Active
	}
	if in.Password != nil {
		u.PasswordHash = hash
	}
	if wasAdmin && (u.Role != model.Admin || !u.Active) {
		var count int
		if err = tx.QueryRowContext(c.Request.Context(), "SELECT COUNT(*) FROM users WHERE tenant_id=? AND role='admin' AND active=TRUE", tenant).Scan(&count); err != nil {
			databaseError(c, err)
			return
		}
		if count <= 1 {
			fail(c, 409, "tenant must retain at least one active admin")
			return
		}
	}
	if _, err = tx.ExecContext(c.Request.Context(), "UPDATE users SET name=?,email=?,role=?,active=?,password_hash=? WHERE tenant_id=? AND id=?", u.Name, u.Email, u.Role, u.Active, u.PasswordHash, tenant, id); err != nil {
		databaseError(c, err)
		return
	}
	if in.Password != nil || in.Role != nil || in.Active != nil || in.Email != nil {
		if _, err = tx.ExecContext(c.Request.Context(), "DELETE FROM sessions WHERE user_id=?", id); err != nil {
			databaseError(c, err)
			return
		}
	}
	if err = tx.Commit(); err != nil {
		databaseError(c, err)
		return
	}
	if deleted {
		c.Status(204)
	} else {
		c.JSON(200, u)
	}
}
