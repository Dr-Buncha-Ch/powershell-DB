-- ------------------------------------------------ identity

CREATE TABLE users (
    user_id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    email         VARCHAR(320) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    company_name  VARCHAR(100) NULL,
    phone         VARCHAR(40) NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at    TIMESTAMP NULL
) ENGINE=INNODB;

CREATE TABLE addresses (
    address_id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id             BIGINT NOT NULL,
    label               VARCHAR(40) NOT NULL DEFAULT 'Primary',
    line1               VARCHAR(255) NOT NULL,
    line2               VARCHAR(255) NULL,
    city                VARCHAR(100) NOT NULL,
    region              VARCHAR(100) NULL,
    postal_code         VARCHAR(20) NULL,
    country_code        CHAR(2) NOT NULL,
    is_default_shipping BOOLEAN NOT NULL DEFAULT FALSE,
    is_default_billing  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_addresses_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=INNODB;

-- ------------------------------------------------ catalog

CREATE TABLE categories (
    category_id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    parent_category_id BIGINT NULL,
    name               VARCHAR(255) NOT NULL,
    slug               VARCHAR(255) NOT NULL UNIQUE,
    description        TEXT NULL,
    created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_categories_parent FOREIGN KEY (parent_category_id)
        REFERENCES categories (category_id) ON DELETE RESTRICT
) ENGINE=INNODB;

CREATE TABLE products (
    product_id  BIGINT AUTO_INCREMENT PRIMARY KEY,
    category_id BIGINT NOT NULL,
    name        VARCHAR(255) NOT NULL,
    slug        VARCHAR(255) NOT NULL UNIQUE,
    description TEXT NULL,
    attributes  JSON NULL,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at  TIMESTAMP NULL,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id)
        REFERENCES categories (category_id) ON DELETE RESTRICT,
    FULLTEXT INDEX ft_products_search (name, description)
) ENGINE=INNODB;

CREATE TABLE product_variants (
    variant_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT NOT NULL,
    sku        VARCHAR(64) NOT NULL UNIQUE,
    name       VARCHAR(255) NOT NULL DEFAULT 'Default',
    price      DECIMAL(12,2) NOT NULL CHECK (price >= 0),
    currency   CHAR(3) NOT NULL DEFAULT 'USD',
    attributes JSON NULL,
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_variants_product FOREIGN KEY (product_id)
        REFERENCES products (product_id) ON DELETE CASCADE
) ENGINE=INNODB;

CREATE TABLE product_images (
    image_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT NOT NULL,
    url        VARCHAR(512) NOT NULL,
    alt_text   VARCHAR(255) NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_images_product FOREIGN KEY (product_id)
        REFERENCES products (product_id) ON DELETE CASCADE,
    UNIQUE KEY uq_product_images_sort (product_id, sort_order)
) ENGINE=INNODB;

-- ------------------------------------------------ inventory

CREATE TABLE inventory (
    variant_id        BIGINT PRIMARY KEY,
    quantity_on_hand  INT NOT NULL CHECK (quantity_on_hand >= 0),
    quantity_reserved INT NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_inventory_variant FOREIGN KEY (variant_id)
        REFERENCES product_variants (variant_id) ON DELETE CASCADE
) ENGINE=INNODB;

-- ------------------------------------------------ fulfillment masters

CREATE TABLE carriers (
    carrier_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(255) NOT NULL UNIQUE,
    phone      VARCHAR(40) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=INNODB;

-- ------------------------------------------------ carts

CREATE TABLE carts (
    cart_id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id        BIGINT NULL,  -- NULL = guest cart
    session_token  CHAR(36) NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'converted', 'abandoned')),
    -- MySQL has no partial indexes; this generated column is non-NULL only
    -- for active user carts, so the unique key below enforces "one active
    -- cart per user" (NULLs never collide)
    active_user_id BIGINT GENERATED ALWAYS AS (IF(status = 'active', user_id, NULL)) STORED,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- RESTRICT (not CASCADE like the PostgreSQL version): MySQL forbids
    -- CASCADE on the base column of a stored generated column
    CONSTRAINT fk_carts_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT,
    UNIQUE KEY uq_carts_active_user (active_user_id)
) ENGINE=INNODB;

CREATE TABLE cart_items (
    cart_id    BIGINT NOT NULL,
    variant_id BIGINT NOT NULL,
    qty        INT NOT NULL CHECK (qty > 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (cart_id, variant_id),
    CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id)
        REFERENCES carts (cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_items_variant FOREIGN KEY (variant_id)
        REFERENCES product_variants (variant_id) ON DELETE RESTRICT
) ENGINE=INNODB;

-- ------------------------------------------------ orders

CREATE TABLE orders (
    order_id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id           BIGINT NOT NULL,
    order_number      VARCHAR(32) NOT NULL UNIQUE,
    status            VARCHAR(20) NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'paid', 'processing',
                                        'shipped', 'delivered', 'cancelled')),
    currency          CHAR(3) NOT NULL DEFAULT 'USD',
    subtotal          DECIMAL(12,2) NOT NULL CHECK (subtotal >= 0),
    discount_total    DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
    shipping_total    DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (shipping_total >= 0),
    grand_total       DECIMAL(12,2) NOT NULL CHECK (grand_total >= 0),
    -- ship-to snapshot: survives later edits to the user's saved addresses
    ship_name         VARCHAR(255) NULL,
    ship_line1        VARCHAR(255) NULL,
    ship_city         VARCHAR(100) NULL,
    ship_region       VARCHAR(100) NULL,
    ship_postal_code  VARCHAR(20) NULL,
    ship_country_code CHAR(2) NULL,
    ordered_at        TIMESTAMP NOT NULL,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT,
    INDEX idx_orders_status (status),
    INDEX idx_orders_ordered_at (ordered_at)
) ENGINE=INNODB;

CREATE TABLE order_items (
    order_id     BIGINT NOT NULL,
    variant_id   BIGINT NOT NULL,
    -- snapshots: survive later catalog edits
    product_name VARCHAR(255) NOT NULL,
    sku          VARCHAR(64) NOT NULL,
    unit_price   DECIMAL(12,2) NOT NULL CHECK (unit_price >= 0),
    qty          INT NOT NULL CHECK (qty > 0),
    discount     DECIMAL(4,3) NOT NULL DEFAULT 0 CHECK (discount >= 0 AND discount <= 1),
    line_total   DECIMAL(12,2) GENERATED ALWAYS AS (ROUND(unit_price * qty * (1 - discount), 2)) STORED,
    PRIMARY KEY (order_id, variant_id),
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_variant FOREIGN KEY (variant_id)
        REFERENCES product_variants (variant_id) ON DELETE RESTRICT
) ENGINE=INNODB;

CREATE TABLE order_status_history (
    history_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id   BIGINT NOT NULL,
    status     VARCHAR(20) NOT NULL
               CHECK (status IN ('pending', 'paid', 'processing',
                                 'shipped', 'delivered', 'cancelled')),
    note       VARCHAR(255) NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_history_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id) ON DELETE CASCADE
) ENGINE=INNODB;

CREATE TABLE payments (
    payment_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id     BIGINT NOT NULL,
    amount       DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
    currency     CHAR(3) NOT NULL DEFAULT 'USD',
    provider     VARCHAR(20) NOT NULL CHECK (provider IN ('card', 'paypal', 'bank_transfer')),
    provider_ref VARCHAR(64) NULL,  -- gateway reference only; never store card data (PCI)
    status       VARCHAR(20) NOT NULL
                 CHECK (status IN ('pending', 'authorized', 'captured',
                                   'failed', 'refunded')),
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id) ON DELETE CASCADE
) ENGINE=INNODB;

CREATE TABLE shipments (
    shipment_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id        BIGINT NOT NULL,
    carrier_id      BIGINT NOT NULL,
    tracking_number VARCHAR(64) NULL,
    shipped_at      TIMESTAMP NULL,
    delivered_at    TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_shipments_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_shipments_carrier FOREIGN KEY (carrier_id)
        REFERENCES carriers (carrier_id) ON DELETE RESTRICT,
    CONSTRAINT chk_shipments_dates
        CHECK (delivered_at IS NULL OR shipped_at IS NULL OR delivered_at >= shipped_at)
) ENGINE=INNODB;

-- Append-only stock ledger. Snapshot lives in inventory; the seed keeps
-- sum(quantity_delta) = inventory.quantity_on_hand for every variant.
CREATE TABLE inventory_movements (
    movement_id    BIGINT AUTO_INCREMENT PRIMARY KEY,
    variant_id     BIGINT NOT NULL,
    quantity_delta INT NOT NULL CHECK (quantity_delta <> 0),
    reason         VARCHAR(20) NOT NULL
                   CHECK (reason IN ('restock', 'sale', 'return', 'adjustment')),
    order_id       BIGINT NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_movements_variant FOREIGN KEY (variant_id)
        REFERENCES product_variants (variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_movements_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id) ON DELETE SET NULL
) ENGINE=INNODB;

