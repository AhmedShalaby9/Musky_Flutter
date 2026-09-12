CREATE TABLE IF NOT EXISTS products (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 tenant_id BIGINT UNSIGNED NOT NULL,
 title VARCHAR(150) NOT NULL,
 code VARCHAR(80) NOT NULL,
 quantity BIGINT NOT NULL DEFAULT 0,
 pieces_per_unit BIGINT NOT NULL,
 unit_price_minor BIGINT NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE,
 version BIGINT NOT NULL DEFAULT 1,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
 UNIQUE KEY uq_product_code (tenant_id, code),
 UNIQUE KEY uq_tenant_product (tenant_id, id),
 CONSTRAINT fk_product_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id),
 CONSTRAINT ck_product_numbers CHECK (quantity BETWEEN 0 AND 1000000000 AND pieces_per_unit BETWEEN 1 AND 1000000 AND unit_price_minor BETWEEN 0 AND 1000000000000)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS invoice_counters (
 tenant_id BIGINT UNSIGNED PRIMARY KEY,
 next_number BIGINT NOT NULL DEFAULT 1,
 CONSTRAINT fk_counter_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS invoices (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 tenant_id BIGINT UNSIGNED NOT NULL,
 client_id BIGINT UNSIGNED NOT NULL,
 created_by_user_id BIGINT UNSIGNED NOT NULL,
 number BIGINT NULL,
 status VARCHAR(20) NOT NULL DEFAULT 'draft',
 currency CHAR(3) NOT NULL DEFAULT 'EGP',
 issue_date DATE NOT NULL,
 client_name VARCHAR(150) NOT NULL,
 client_address VARCHAR(500) NOT NULL DEFAULT '',
 notes VARCHAR(2000) NOT NULL DEFAULT '',
 void_reason VARCHAR(500) NOT NULL DEFAULT '',
 total_minor BIGINT NOT NULL DEFAULT 0,
 version BIGINT NOT NULL DEFAULT 1,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 posted_at DATETIME(6) NULL,
 voided_at DATETIME(6) NULL,
 UNIQUE KEY uq_tenant_invoice (tenant_id,id),
 UNIQUE KEY uq_invoice_number (tenant_id,number),
 CONSTRAINT fk_invoice_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id),
 CONSTRAINT fk_invoice_client FOREIGN KEY (tenant_id,client_id) REFERENCES clients(tenant_id,id),
 CONSTRAINT fk_invoice_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id),
 CONSTRAINT ck_invoice_status CHECK (status IN ('draft','posted','void','cancelled')),
 CONSTRAINT ck_invoice_money CHECK (currency='EGP' AND total_minor BETWEEN 0 AND 100000000000000)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS invoice_items (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 tenant_id BIGINT UNSIGNED NOT NULL,
 invoice_id BIGINT UNSIGNED NOT NULL,
 product_id BIGINT UNSIGNED NOT NULL,
 title VARCHAR(150) NOT NULL,
 code VARCHAR(80) NOT NULL,
 pieces_per_unit BIGINT NOT NULL,
 quantity BIGINT NOT NULL,
 unit_price_minor BIGINT NOT NULL,
 total_minor BIGINT NOT NULL,
 UNIQUE KEY uq_invoice_product (invoice_id,product_id),
 CONSTRAINT fk_item_invoice FOREIGN KEY (tenant_id,invoice_id) REFERENCES invoices(tenant_id,id),
 CONSTRAINT fk_item_product FOREIGN KEY (tenant_id,product_id) REFERENCES products(tenant_id,id),
 CONSTRAINT ck_item_numbers CHECK (quantity BETWEEN 1 AND 1000000000 AND pieces_per_unit BETWEEN 1 AND 1000000 AND unit_price_minor BETWEEN 0 AND 1000000000000 AND total_minor BETWEEN 0 AND 100000000000000)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS stock_movements (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 tenant_id BIGINT UNSIGNED NOT NULL,
 product_id BIGINT UNSIGNED NOT NULL,
 invoice_id BIGINT UNSIGNED NULL,
 created_by_user_id BIGINT UNSIGNED NOT NULL,
 kind VARCHAR(20) NOT NULL,
 quantity_delta BIGINT NOT NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 UNIQUE KEY uq_stock_invoice (invoice_id,product_id,kind),
 CONSTRAINT fk_stock_product FOREIGN KEY (tenant_id,product_id) REFERENCES products(tenant_id,id),
 CONSTRAINT fk_stock_invoice FOREIGN KEY (tenant_id,invoice_id) REFERENCES invoices(tenant_id,id),
 CONSTRAINT fk_stock_actor FOREIGN KEY (created_by_user_id) REFERENCES users(id),
 CONSTRAINT ck_stock_kind CHECK (kind IN ('opening','adjustment','sale','void'))
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS client_ledger (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 tenant_id BIGINT UNSIGNED NOT NULL,
 client_id BIGINT UNSIGNED NOT NULL,
 invoice_id BIGINT UNSIGNED NOT NULL,
 kind VARCHAR(20) NOT NULL,
 amount_minor BIGINT NOT NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 UNIQUE KEY uq_ledger_invoice (invoice_id,kind),
 CONSTRAINT fk_ledger_client FOREIGN KEY (tenant_id,client_id) REFERENCES clients(tenant_id,id),
 CONSTRAINT fk_ledger_invoice FOREIGN KEY (tenant_id,invoice_id) REFERENCES invoices(tenant_id,id),
 CONSTRAINT ck_ledger_kind CHECK (kind IN ('invoice','void'))
) ENGINE=InnoDB;
