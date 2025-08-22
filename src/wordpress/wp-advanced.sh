#!/bin/bash
# Advanced WordPress Development Environment

set -e

WARP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$WARP_DIR/src/core/logger.sh"
source "$WARP_DIR/src/core/utils.sh"

# WordPress project scaffolding with modern tooling
create_modern_wp_plugin() {
    local plugin_name="$1"
    local description="$2"
    
    log_info "Creating modern WordPress plugin with full toolchain..."
    
    # Advanced plugin structure
    mkdir -p {src/{blocks,components,hooks,utils},assets/{scss,js,images},tests/{unit,integration,e2e},build,languages}
    
    # Modern package.json with full build system
    cat > package.json << EOF
{
  "name": "$plugin_name",
  "version": "1.0.0",
  "description": "$description",
  "scripts": {
    "dev": "webpack --mode development --watch",
    "build": "webpack --mode production",
    "build:blocks": "@wordpress/scripts build",
    "start": "@wordpress/scripts start",
    "test": "jest",
    "test:e2e": "playwright test",
    "lint:js": "eslint assets/js src/",
    "lint:css": "stylelint assets/scss/**/*.scss",
    "lint:php": "phpcs --standard=WordPress .",
    "format:js": "prettier --write assets/js src/",
    "format:php": "phpcbf --standard=WordPress .",
    "translate": "wp i18n make-pot . languages/$plugin_name.pot"
  },
  "dependencies": {
    "@wordpress/block-editor": "^12.0.0",
    "@wordpress/blocks": "^12.0.0",
    "@wordpress/components": "^25.0.0",
    "@wordpress/element": "^5.0.0",
    "@wordpress/i18n": "^4.0.0"
  },
  "devDependencies": {
    "@wordpress/scripts": "^26.0.0",
    "@wordpress/eslint-plugin": "^17.0.0",
    "@wordpress/prettier-config": "^3.0.0",
    "@playwright/test": "^1.40.0",
    "webpack": "^5.89.0",
    "webpack-cli": "^5.1.4",
    "sass": "^1.69.5",
    "sass-loader": "^13.3.2",
    "css-loader": "^6.8.1",
    "mini-css-extract-plugin": "^2.7.6",
    "stylelint": "^15.11.0",
    "stylelint-config-wordpress": "^17.0.0",
    "jest": "^29.7.0",
    "@testing-library/jest-dom": "^6.1.5"
  },
  "browserslist": [
    "extends @wordpress/browserslist-config"
  ]
}
EOF

    # Modern webpack configuration
    cat > webpack.config.js << 'EOF'
const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = (env, argv) => {
    const isProduction = argv.mode === 'production';
    
    return {
        entry: {
            'admin': './assets/js/admin.js',
            'frontend': './assets/js/frontend.js',
            'blocks': './src/blocks/index.js'
        },
        output: {
            path: path.resolve(__dirname, 'build'),
            filename: '[name].js',
            clean: true
        },
        module: {
            rules: [
                {
                    test: /\.js$/,
                    exclude: /node_modules/,
                    use: {
                        loader: 'babel-loader',
                        options: {
                            presets: ['@wordpress/babel-preset-default']
                        }
                    }
                },
                {
                    test: /\.scss$/,
                    use: [
                        MiniCssExtractPlugin.loader,
                        'css-loader',
                        'sass-loader'
                    ]
                }
            ]
        },
        plugins: [
            new MiniCssExtractPlugin({
                filename: '[name].css'
            })
        ],
        externals: {
            '@wordpress/blocks': 'wp.blocks',
            '@wordpress/element': 'wp.element',
            '@wordpress/components': 'wp.components',
            '@wordpress/block-editor': 'wp.blockEditor'
        },
        devtool: isProduction ? false : 'source-map'
    };
};
EOF

    # Modern PHP plugin structure with namespaces
    cat > "$plugin_name.php" << EOF
<?php
/**
 * Plugin Name: $plugin_name
 * Description: $description
 * Version: 1.0.0
 * Requires at least: 6.0
 * Requires PHP: 8.0
 * Author: Developer
 * Text Domain: $plugin_name
 * Domain Path: /languages
 *
 * @package $(echo $plugin_name | sed 's/-//g' | sed 's/\b\w/\U&/g')
 */

namespace $(echo $plugin_name | sed 's/-//g' | sed 's/\b\w/\U&/g');

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Define constants
define('$(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION', '1.0.0');
define('$(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_FILE', __FILE__);
define('$(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('$(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_URL', plugin_dir_url(__FILE__));

// Autoloader
require_once __DIR__ . '/vendor/autoload.php';

/**
 * Main plugin class
 */
class Plugin {
    /**
     * Instance
     */
    private static \$instance = null;
    
    /**
     * Get instance
     */
    public static function get_instance(): self {
        if (null === self::\$instance) {
            self::\$instance = new self();
        }
        return self::\$instance;
    }
    
    /**
     * Constructor
     */
    private function __construct() {
        add_action('init', [\$this, 'init']);
        add_action('enqueue_block_editor_assets', [\$this, 'enqueue_block_editor_assets']);
        
        register_activation_hook(__FILE__, [\$this, 'activate']);
        register_deactivation_hook(__FILE__, [\$this, 'deactivate']);
    }
    
    /**
     * Initialize
     */
    public function init(): void {
        // Load text domain
        load_plugin_textdomain('$plugin_name', false, dirname(plugin_basename(__FILE__)) . '/languages');
        
        // Initialize components
        new Admin\\Admin();
        new Frontend\\Frontend();
        new API\\RestAPI();
        new Blocks\\BlockManager();
    }
    
    /**
     * Enqueue block editor assets
     */
    public function enqueue_block_editor_assets(): void {
        wp_enqueue_script(
            '$plugin_name-blocks',
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_URL . 'build/blocks.js',
            ['wp-blocks', 'wp-element', 'wp-editor'],
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION,
            true
        );
        
        wp_enqueue_style(
            '$plugin_name-blocks',
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_URL . 'build/blocks.css',
            [],
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION
        );
    }
    
    /**
     * Activation
     */
    public function activate(): void {
        // Create database tables
        \$this->create_tables();
        
        // Set default options
        \$this->set_default_options();
        
        // Flush rewrite rules
        flush_rewrite_rules();
    }
    
    /**
     * Deactivation
     */
    public function deactivate(): void {
        flush_rewrite_rules();
    }
    
    /**
     * Create database tables
     */
    private function create_tables(): void {
        global \$wpdb;
        
        \$table_name = \$wpdb->prefix . '$(echo $plugin_name | tr '-' '_')_data';
        
        \$charset_collate = \$wpdb->get_charset_collate();
        
        \$sql = "CREATE TABLE \$table_name (
            id mediumint(9) NOT NULL AUTO_INCREMENT,
            title tinytext NOT NULL,
            content text NOT NULL,
            meta longtext,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) \$charset_collate;";
        
        require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
        dbDelta(\$sql);
    }
    
    /**
     * Set default options
     */
    private function set_default_options(): void {
        \$defaults = [
            'version' => $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION,
            'settings' => [
                'enabled' => true,
                'api_enabled' => true,
            ],
        ];
        
        add_option('$(echo $plugin_name | tr '-' '_')_options', \$defaults);
    }
}

// Initialize plugin
Plugin::get_instance();
EOF

    # Modern composer.json with autoloading
    cat > composer.json << EOF
{
    "name": "$(echo $GITHUB_USERNAME | tr '[:upper:]' '[:lower:]')/$plugin_name",
    "description": "$description",
    "type": "wordpress-plugin",
    "require": {
        "php": ">=8.0"
    },
    "require-dev": {
        "phpunit/phpunit": "^10.0",
        "squizlabs/php_codesniffer": "^3.7",
        "wp-coding-standards/wpcs": "^3.0",
        "phpstan/phpstan": "^1.10",
        "phpmd/phpmd": "^2.13",
        "brain/monkey": "^2.6",
        "yoast/phpunit-polyfills": "^2.0"
    },
    "autoload": {
        "psr-4": {
            "$(echo $plugin_name | sed 's/-//g' | sed 's/\b\w/\U&/g')\\\\": "src/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "$(echo $plugin_name | sed 's/-//g' | sed 's/\b\w/\U&/g')\\\\Tests\\\\": "tests/"
        }
    },
    "scripts": {
        "test": "phpunit",
        "cs": "phpcs",
        "cbf": "phpcbf",
        "analyse": "phpstan analyse"
    },
    "config": {
        "allow-plugins": {
            "dealerdirect/phpcodesniffer-composer-installer": true
        }
    }
}
EOF

    # Create modern PHP class structure
    create_modern_php_classes "$plugin_name"
    
    # Create modern JavaScript structure
    create_modern_js_structure "$plugin_name"
    
    # Create advanced testing setup
    create_advanced_testing_setup "$plugin_name"
    
    # Create development workflow files
    create_development_workflow "$plugin_name"
    
    log_success "Modern WordPress plugin created with full toolchain"
}

# Create modern PHP class structure
create_modern_php_classes() {
    local plugin_name="$1"
    local namespace=$(echo $plugin_name | sed 's/-//g' | sed 's/\b\w/\U&/g')
    
    # Admin class
    mkdir -p src/Admin
    cat > src/Admin/Admin.php << EOF
<?php
/**
 * Admin functionality
 *
 * @package $namespace
 */

namespace $namespace\\Admin;

/**
 * Admin class
 */
class Admin {
    
    /**
     * Constructor
     */
    public function __construct() {
        add_action('admin_menu', [\$this, 'add_admin_menu']);
        add_action('admin_enqueue_scripts', [\$this, 'enqueue_scripts']);
        add_action('admin_init', [\$this, 'register_settings']);
    }
    
    /**
     * Add admin menu
     */
    public function add_admin_menu(): void {
        add_options_page(
            __('$plugin_name Settings', '$plugin_name'),
            __('$plugin_name', '$plugin_name'),
            'manage_options',
            '$plugin_name-settings',
            [\$this, 'settings_page']
        );
    }
    
    /**
     * Enqueue admin scripts
     */
    public function enqueue_scripts(\$hook): void {
        if ('settings_page_$plugin_name-settings' !== \$hook) {
            return;
        }
        
        wp_enqueue_script(
            '$plugin_name-admin',
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_URL . 'build/admin.js',
            ['jquery'],
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION,
            true
        );
        
        wp_enqueue_style(
            '$plugin_name-admin',
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_URL . 'build/admin.css',
            [],
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION
        );
        
        wp_localize_script('$plugin_name-admin', '${plugin_name//-/}Admin', [
            'ajaxUrl' => admin_url('admin-ajax.php'),
            'nonce' => wp_create_nonce('$plugin_name-admin'),
            'strings' => [
                'saved' => __('Settings saved successfully!', '$plugin_name'),
                'error' => __('An error occurred. Please try again.', '$plugin_name'),
            ],
        ]);
    }
    
    /**
     * Register settings
     */
    public function register_settings(): void {
        register_setting('$plugin_name-settings', '$(echo $plugin_name | tr '-' '_')_options', [
            'sanitize_callback' => [\$this, 'sanitize_options'],
        ]);
    }
    
    /**
     * Settings page
     */
    public function settings_page(): void {
        include $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_DIR . 'templates/admin/settings.php';
    }
    
    /**
     * Sanitize options
     */
    public function sanitize_options(array \$options): array {
        // Sanitize options here
        return \$options;
    }
}
EOF

    # API class
    mkdir -p src/API
    cat > src/API/RestAPI.php << EOF
<?php
/**
 * REST API functionality
 *
 * @package $namespace
 */

namespace $namespace\\API;

use WP_REST_Request;
use WP_REST_Response;
use WP_Error;

/**
 * REST API class
 */
class RestAPI {
    
    /**
     * Constructor
     */
    public function __construct() {
        add_action('rest_api_init', [\$this, 'register_routes']);
    }
    
    /**
     * Register REST API routes
     */
    public function register_routes(): void {
        register_rest_route('$plugin_name/v1', '/items', [
            [
                'methods' => 'GET',
                'callback' => [\$this, 'get_items'],
                'permission_callback' => [\$this, 'get_items_permissions_check'],
            ],
            [
                'methods' => 'POST',
                'callback' => [\$this, 'create_item'],
                'permission_callback' => [\$this, 'create_item_permissions_check'],
                'args' => [
                    'title' => [
                        'required' => true,
                        'type' => 'string',
                        'sanitize_callback' => 'sanitize_text_field',
                    ],
                    'content' => [
                        'required' => true,
                        'type' => 'string',
                        'sanitize_callback' => 'wp_kses_post',
                    ],
                ],
            ],
        ]);
        
        register_rest_route('$plugin_name/v1', '/items/(?P<id>\\d+)', [
            [
                'methods' => 'GET',
                'callback' => [\$this, 'get_item'],
                'permission_callback' => [\$this, 'get_item_permissions_check'],
            ],
            [
                'methods' => 'PUT',
                'callback' => [\$this, 'update_item'],
                'permission_callback' => [\$this, 'update_item_permissions_check'],
            ],
            [
                'methods' => 'DELETE',
                'callback' => [\$this, 'delete_item'],
                'permission_callback' => [\$this, 'delete_item_permissions_check'],
            ],
        ]);
    }
    
    /**
     * Get items
     */
    public function get_items(WP_REST_Request \$request): WP_REST_Response {
        // Implementation here
        return new WP_REST_Response([
            'items' => [],
            'total' => 0,
        ]);
    }
    
    /**
     * Permission check for getting items
     */
    public function get_items_permissions_check(): bool {
        return current_user_can('read');
    }
    
    /**
     * Create item
     */
    public function create_item(WP_REST_Request \$request): WP_REST_Response|WP_Error {
        // Implementation here
        return new WP_REST_Response(['id' => 1], 201);
    }
    
    /**
     * Permission check for creating items
     */
    public function create_item_permissions_check(): bool {
        return current_user_can('edit_posts');
    }
    
    /**
     * Get single item
     */
    public function get_item(WP_REST_Request \$request): WP_REST_Response|WP_Error {
        \$id = \$request->get_param('id');
        // Implementation here
        return new WP_REST_Response(['id' => \$id]);
    }
    
    /**
     * Permission check for getting single item
     */
    public function get_item_permissions_check(): bool {
        return current_user_can('read');
    }
    
    /**
     * Update item
     */
    public function update_item(WP_REST_Request \$request): WP_REST_Response|WP_Error {
        // Implementation here
        return new WP_REST_Response(['updated' => true]);
    }
    
    /**
     * Permission check for updating items
     */
    public function update_item_permissions_check(): bool {
        return current_user_can('edit_posts');
    }
    
    /**
     * Delete item
     */
    public function delete_item(WP_REST_Request \$request): WP_REST_Response|WP_Error {
        // Implementation here
        return new WP_REST_Response(['deleted' => true]);
    }
    
    /**
     * Permission check for deleting items
     */
    public function delete_item_permissions_check(): bool {
        return current_user_can('delete_posts');
    }
}
EOF

    # Blocks manager
    mkdir -p src/Blocks
    cat > src/Blocks/BlockManager.php << EOF
<?php
/**
 * Block management
 *
 * @package $namespace
 */

namespace $namespace\\Blocks;

/**
 * Block Manager class
 */
class BlockManager {
    
    /**
     * Constructor
     */
    public function __construct() {
        add_action('init', [\$this, 'register_blocks']);
    }
    
    /**
     * Register blocks
     */
    public function register_blocks(): void {
        register_block_type($(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_DIR . 'src/blocks/example-block');
    }
}
EOF

    # Frontend class
    mkdir -p src/Frontend
    cat > src/Frontend/Frontend.php << EOF
<?php
/**
 * Frontend functionality
 *
 * @package $namespace
 */

namespace $namespace\\Frontend;

/**
 * Frontend class
 */
class Frontend {
    
    /**
     * Constructor
     */
    public function __construct() {
        add_action('wp_enqueue_scripts', [\$this, 'enqueue_scripts']);
        add_shortcode('$plugin_name', [\$this, 'shortcode']);
    }
    
    /**
     * Enqueue frontend scripts
     */
    public function enqueue_scripts(): void {
        wp_enqueue_script(
            '$plugin_name-frontend',
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_URL . 'build/frontend.js',
            ['jquery'],
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION,
            true
        );
        
        wp_enqueue_style(
            '$plugin_name-frontend',
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_URL . 'build/frontend.css',
            [],
            $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION
        );
        
        wp_localize_script('$plugin_name-frontend', '${plugin_name//-/}Frontend', [
            'ajaxUrl' => admin_url('admin-ajax.php'),
            'nonce' => wp_create_nonce('$plugin_name-frontend'),
            'apiUrl' => rest_url('$plugin_name/v1/'),
        ]);
    }
    
    /**
     * Shortcode handler
     */
    public function shortcode(\$atts, \$content = ''): string {
        \$atts = shortcode_atts([
            'id' => '',
            'class' => '',
            'type' => 'default',
        ], \$atts, '$plugin_name');
        
        ob_start();
        include $(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_DIR . 'templates/frontend/shortcode.php';
        return ob_get_clean();
    }
}
EOF
}

# Create modern JavaScript structure
create_modern_js_structure() {
    local plugin_name="$1"
    
    # Modern block development
    mkdir -p src/blocks/example-block
    cat > src/blocks/example-block/block.json << EOF
{
    "name": "$plugin_name/example-block",
    "version": "1.0.0",
    "title": "Example Block",
    "category": "widgets",
    "icon": "admin-plugins",
    "description": "An example block for $plugin_name",
    "supports": {
        "html": false,
        "color": {
            "background": true,
            "text": true
        },
        "spacing": {
            "padding": true,
            "margin": true
        }
    },
    "attributes": {
        "message": {
            "type": "string",
            "default": "Hello World!"
        },
        "alignment": {
            "type": "string",
            "default": "center"
        }
    },
    "textdomain": "$plugin_name",
    "editorScript": "file:./index.js",
    "editorStyle": "file:./editor.css",
    "style": "file:./style.css"
}
EOF

    cat > src/blocks/example-block/index.js << 'EOF'
import { registerBlockType } from '@wordpress/blocks';
import { useBlockProps, RichText, InspectorControls, BlockControls, AlignmentToolbar } from '@wordpress/block-editor';
import { PanelBody, TextControl } from '@wordpress/components';
import { __ } from '@wordpress/i18n';

registerBlockType('PLUGIN_NAME/example-block', {
    edit: ({ attributes, setAttributes }) => {
        const { message, alignment } = attributes;
        const blockProps = useBlockProps({
            className: `has-text-align-${alignment}`,
        });

        return (
            <>
                <InspectorControls>
                    <PanelBody title={__('Settings', 'PLUGIN_NAME')}>
                        <TextControl
                            label={__('Message', 'PLUGIN_NAME')}
                            value={message}
                            onChange={(value) => setAttributes({ message: value })}
                        />
                    </PanelBody>
                </InspectorControls>
                
                <BlockControls>
                    <AlignmentToolbar
                        value={alignment}
                        onChange={(value) => setAttributes({ alignment: value })}
                    />
                </BlockControls>
                
                <div {...blockProps}>
                    <RichText
                        tagName="p"
                        value={message}
                        onChange={(value) => setAttributes({ message: value })}
                        placeholder={__('Enter your message...', 'PLUGIN_NAME')}
                    />
                </div>
            </>
        );
    },

    save: ({ attributes }) => {
        const { message, alignment } = attributes;
        const blockProps = useBlockProps.save({
            className: `has-text-align-${alignment}`,
        });

        return (
            <div {...blockProps}>
                <RichText.Content tagName="p" value={message} />
            </div>
        );
    },
});
EOF

    # Modern admin JavaScript
    mkdir -p assets/js
    cat > assets/js/admin.js << 'EOF'
(function($) {
    'use strict';

    const PluginAdmin = {
        init() {
            this.bindEvents();
            this.initComponents();
        },

        bindEvents() {
            $('#plugin-settings-form').on('submit', this.handleFormSubmit.bind(this));
            $('.plugin-toggle').on('change', this.handleToggleChange.bind(this));
        },

        initComponents() {
            // Initialize any admin components
            this.initTabs();
            this.initTooltips();
        },

        initTabs() {
            $('.nav-tab').on('click', function(e) {
                e.preventDefault();
                
                const target = $(this).attr('href');
                $('.nav-tab').removeClass('nav-tab-active');
                $(this).addClass('nav-tab-active');
                
                $('.tab-content').hide();
                $(target).show();
            });
        },

        initTooltips() {
            $('[data-tooltip]').each(function() {
                $(this).attr('title', $(this).data('tooltip'));
            });
        },

        handleFormSubmit(e) {
            e.preventDefault();
            
            const formData = new FormData(e.target);
            formData.append('action', 'save_plugin_settings');
            formData.append('nonce', window.pluginAdmin.nonce);

            this.showSpinner();

            $.ajax({
                url: window.pluginAdmin.ajaxUrl,
                method: 'POST',
                data: formData,
                processData: false,
                contentType: false,
                success: (response) => {
                    this.hideSpinner();
                    if (response.success) {
                        this.showNotice('success', window.pluginAdmin.strings.saved);
                    } else {
                        this.showNotice('error', response.data || window.pluginAdmin.strings.error);
                    }
                },
                error: () => {
                    this.hideSpinner();
                    this.showNotice('error', window.pluginAdmin.strings.error);
                }
            });
        },

        handleToggleChange(e) {
            const $toggle = $(e.target);
            const setting = $toggle.data('setting');
            const value = $toggle.is(':checked');

            // Update setting via AJAX
            $.post(window.pluginAdmin.ajaxUrl, {
                action: 'update_plugin_setting',
                setting: setting,
                value: value,
                nonce: window.pluginAdmin.nonce
            });
        },

        showSpinner() {
            $('.spinner').addClass('is-active');
        },

        hideSpinner() {
            $('.spinner').removeClass('is-active');
        },

        showNotice(type, message) {
            const $notice = $(`
                <div class="notice notice-${type} is-dismissible">
                    <p>${message}</p>
                    <button type="button" class="notice-dismiss">
                        <span class="screen-reader-text">Dismiss this notice.</span>
                    </button>
                </div>
            `);

            $('.wrap h1').after($notice);

            setTimeout(() => {
                $notice.fadeOut(() => $notice.remove());
            }, 5000);
        }
    };

    $(document).ready(() => {
        PluginAdmin.init();
    });

})(jQuery);
EOF

    # Modern frontend JavaScript
    cat > assets/js/frontend.js << 'EOF'
(function() {
    'use strict';

    const PluginFrontend = {
        init() {
            this.bindEvents();
            this.initComponents();
        },

        bindEvents() {
            document.addEventListener('DOMContentLoaded', () => {
                this.onDOMReady();
            });
        },

        onDOMReady() {
            this.initBlocks();
            this.initInteractiveElements();
        },

        initBlocks() {
            const blocks = document.querySelectorAll('.wp-block-PLUGIN_NAME-example-block');
            blocks.forEach(block => {
                this.enhanceBlock(block);
            });
        },

        enhanceBlock(block) {
            // Add interactive functionality to blocks
            block.addEventListener('click', (e) => {
                if (e.target.matches('.interactive-element')) {
                    this.handleInteraction(e.target);
                }
            });
        },

initInteractiveElements() {
            const elements = document.querySelectorAll('[data-plugin-action]');
            elements.forEach(element => {
                element.addEventListener('click', this.handleActionClick.bind(this));
            });
        },

        handleActionClick(e) {
            e.preventDefault();
            
            const action = e.target.dataset.pluginAction;
            const data = JSON.parse(e.target.dataset.pluginData || '{}');
            
            this.performAction(action, data, e.target);
        },

        async performAction(action, data, element) {
            try {
                element.classList.add('loading');
                
                const response = await fetch(window.pluginFrontend.apiUrl + action, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-WP-Nonce': window.pluginFrontend.nonce
                    },
                    body: JSON.stringify(data)
                });
                
                const result = await response.json();
                
                if (result.success) {
                    this.handleActionSuccess(result, element);
                } else {
                    this.handleActionError(result, element);
                }
            } catch (error) {
                this.handleActionError({ message: 'Network error' }, element);
            } finally {
                element.classList.remove('loading');
            }
        },

        handleActionSuccess(result, element) {
            // Handle successful action
            element.classList.add('success');
            setTimeout(() => element.classList.remove('success'), 2000);
            
            // Trigger custom event
            element.dispatchEvent(new CustomEvent('plugin:actionSuccess', {
                detail: result
            }));
        },

        handleActionError(error, element) {
            // Handle action error
            element.classList.add('error');
            setTimeout(() => element.classList.remove('error'), 2000);
            
            console.error('Plugin action error:', error);
        },

        handleInteraction(element) {
            // Handle block interactions
            const interactionType = element.dataset.interaction;
            
            switch (interactionType) {
                case 'toggle':
                    this.toggleElement(element);
                    break;
                case 'expand':
                    this.expandElement(element);
                    break;
                default:
                    console.warn('Unknown interaction type:', interactionType);
            }
        },

        toggleElement(element) {
            element.classList.toggle('active');
        },

        expandElement(element) {
            const content = element.nextElementSibling;
            if (content) {
                content.style.display = content.style.display === 'none' ? 'block' : 'none';
            }
        }
    };

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => PluginFrontend.init());
    } else {
        PluginFrontend.init();
    }

})();
EOF

    # Modern SCSS structure
    mkdir -p assets/scss/{admin,frontend,blocks,components}
    
    cat > assets/scss/admin/main.scss << 'EOF'
// Admin styles
@import '../components/variables';
@import '../components/mixins';

.plugin-admin-page {
    .wrap {
        max-width: 1200px;
        margin: 0 auto;
    }

    .nav-tab-wrapper {
        border-bottom: 1px solid #ccd0d4;
        margin-bottom: 20px;
    }

    .nav-tab {
        &.nav-tab-active {
            background: #fff;
            border-bottom: 1px solid #fff;
        }
    }

    .tab-content {
        background: #fff;
        padding: 20px;
        border: 1px solid #ccd0d4;
        border-radius: 0 0 4px 4px;
    }

    .form-table {
        th {
            width: 200px;
            vertical-align: top;
            padding-top: 15px;
        }

        .description {
            color: #666;
            font-style: italic;
            margin-top: 5px;
        }
    }

    .plugin-toggle {
        position: relative;
        display: inline-block;
        width: 60px;
        height: 34px;

        input {
            opacity: 0;
            width: 0;
            height: 0;

            &:checked + .slider {
                background-color: #2196F3;

                &:before {
                    transform: translateX(26px);
                }
            }
        }

        .slider {
            position: absolute;
            cursor: pointer;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: #ccc;
            transition: .4s;
            border-radius: 34px;

            &:before {
                position: absolute;
                content: "";
                height: 26px;
                width: 26px;
                left: 4px;
                bottom: 4px;
                background-color: white;
                transition: .4s;
                border-radius: 50%;
            }
        }
    }

    .spinner {
        &.is-active {
            visibility: visible;
        }
    }
}

// Component styles
.plugin-card {
    background: #fff;
    border: 1px solid #ccd0d4;
    border-radius: 4px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 1px 1px rgba(0,0,0,0.04);

    .card-header {
        display: flex;
        align-items: center;
        margin-bottom: 15px;

        h3 {
            margin: 0;
            flex: 1;
        }

        .card-actions {
            display: flex;
            gap: 10px;
        }
    }

    .card-content {
        color: #666;
        line-height: 1.5;
    }
}
EOF

    cat > assets/scss/frontend/main.scss << 'EOF'
// Frontend styles
@import '../components/variables';
@import '../components/mixins';

.wp-block-PLUGIN_NAME-example-block {
    padding: 20px;
    border: 1px solid #ddd;
    border-radius: 4px;
    background: #f9f9f9;

    &.has-text-align-left {
        text-align: left;
    }

    &.has-text-align-center {
        text-align: center;
    }

    &.has-text-align-right {
        text-align: right;
    }

    p {
        margin: 0;
        font-size: 16px;
        line-height: 1.5;
    }
}

.plugin-interactive-element {
    cursor: pointer;
    transition: all 0.3s ease;

    &:hover {
        opacity: 0.8;
    }

    &.loading {
        opacity: 0.5;
        pointer-events: none;
        position: relative;

        &::after {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            width: 20px;
            height: 20px;
            margin: -10px 0 0 -10px;
            border: 2px solid #f3f3f3;
            border-top: 2px solid #3498db;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
    }

    &.success {
        background-color: #d4edda;
        border-color: #c3e6cb;
    }

    &.error {
        background-color: #f8d7da;
        border-color: #f5c6cb;
    }
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

.plugin-shortcode {
    margin: 20px 0;
    padding: 15px;
    background: #fff;
    border: 1px solid #ddd;
    border-radius: 4px;

    .shortcode-title {
        margin: 0 0 10px 0;
        font-size: 18px;
        font-weight: 600;
    }

    .shortcode-content {
        color: #666;
        line-height: 1.5;
    }
}
EOF

    cat > assets/scss/components/_variables.scss << 'EOF'
// Colors
$primary-color: #0073aa;
$secondary-color: #006799;
$success-color: #46b450;
$warning-color: #ffb900;
$error-color: #dc3232;

// Typography
$font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif;
$font-size-base: 14px;
$line-height-base: 1.4;

// Spacing
$spacing-xs: 5px;
$spacing-sm: 10px;
$spacing-md: 15px;
$spacing-lg: 20px;
$spacing-xl: 30px;

// Borders
$border-radius: 4px;
$border-color: #ccd0d4;
EOF

    cat > assets/scss/components/_mixins.scss << 'EOF'
// Mixins
@mixin button-style($bg-color: $primary-color, $text-color: #fff) {
    background-color: $bg-color;
    color: $text-color;
    border: none;
    padding: 8px 16px;
    border-radius: $border-radius;
    cursor: pointer;
    text-decoration: none;
    display: inline-block;
    transition: background-color 0.3s ease;

    &:hover {
        background-color: darken($bg-color, 10%);
    }

    &:active {
        background-color: darken($bg-color, 15%);
    }

    &:disabled {
        background-color: lighten($bg-color, 20%);
        cursor: not-allowed;
    }
}

@mixin card-style {
    background: #fff;
    border: 1px solid $border-color;
    border-radius: $border-radius;
    padding: $spacing-lg;
    box-shadow: 0 1px 1px rgba(0,0,0,0.04);
}

@mixin loading-overlay {
    position: relative;

    &::after {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(255, 255, 255, 0.8);
        display: flex;
        align-items: center;
        justify-content: center;
    }
}
EOF
}

# Create advanced testing setup
create_advanced_testing_setup() {
    local plugin_name="$1"
    local namespace=$(echo $plugin_name | sed 's/-//g' | sed 's/\b\w/\U&/g')
    
    # PHPUnit configuration
    cat > phpunit.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="https://schema.phpunit.de/10.0/phpunit.xsd"
         bootstrap="tests/bootstrap.php"
         cacheDirectory=".phpunit.cache"
         executionOrder="depends,defects"
         requireCoverageMetadata="true"
         beStrictAboutCoverageMetadata="true"
         beStrictAboutOutputDuringTests="true"
         failOnRisky="true"
         failOnWarning="true">
    <testsuites>
        <testsuite name="Unit Tests">
            <directory>tests/unit</directory>
        </testsuite>
        <testsuite name="Integration Tests">
            <directory>tests/integration</directory>
        </testsuite>
    </testsuites>
    <source restrictDeprecations="true" restrictNotices="true" restrictWarnings="true">
        <include>
            <directory>src</directory>
        </include>
    </source>
    <coverage>
        <report>
            <html outputDirectory="coverage/html"/>
            <text outputFile="coverage/coverage.txt"/>
            <clover outputFile="coverage/clover.xml"/>
        </report>
    </coverage>
</phpunit>
EOF

    # Test bootstrap
    cat > tests/bootstrap.php << EOF
<?php
/**
 * PHPUnit bootstrap file
 */

// Composer autoloader
require_once __DIR__ . '/../vendor/autoload.php';

// WordPress test environment
\$_tests_dir = getenv('WP_TESTS_DIR');
if (!\$_tests_dir) {
    \$_tests_dir = '/tmp/wordpress-tests-lib';
}

// Give access to tests_add_filter() function
require_once \$_tests_dir . '/includes/functions.php';

/**
 * Manually load the plugin being tested
 */
function _manually_load_plugin() {
    require dirname(__FILE__) . '/../$plugin_name.php';
}
tests_add_filter('muplugins_loaded', '_manually_load_plugin');

// Start up the WP testing environment
require \$_tests_dir . '/includes/bootstrap.php';
EOF

    # Unit test example
    mkdir -p tests/unit
    cat > tests/unit/PluginTest.php << EOF
<?php
/**
 * Plugin unit tests
 */

namespace $namespace\\Tests\\Unit;

use PHPUnit\\Framework\\TestCase;
use $namespace\\Plugin;

/**
 * Plugin test class
 */
class PluginTest extends TestCase {
    
    /**
     * Test plugin instance
     */
    public function test_plugin_instance(): void {
        \$plugin = Plugin::get_instance();
        \$this->assertInstanceOf(Plugin::class, \$plugin);
        
        // Test singleton
        \$plugin2 = Plugin::get_instance();
        \$this->assertSame(\$plugin, \$plugin2);
    }
    
    /**
     * Test plugin constants
     */
    public function test_plugin_constants(): void {
        \$this->assertTrue(defined('$(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION'));
        \$this->assertTrue(defined('$(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_FILE'));
        \$this->assertTrue(defined('$(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_DIR'));
        \$this->assertTrue(defined('$(echo $plugin_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PLUGIN_URL'));
    }
}
EOF

    # Integration test example
    mkdir -p tests/integration
    cat > tests/integration/APITest.php << EOF
<?php
/**
 * API integration tests
 */

namespace $namespace\\Tests\\Integration;

use WP_UnitTestCase;
use WP_REST_Request;

/**
 * API test class
 */
class APITest extends WP_UnitTestCase {
    
    /**
     * Set up
     */
    public function setUp(): void {
        parent::setUp();
        
        // Create test user
        \$this->user_id = \$this->factory->user->create([
            'role' => 'administrator',
        ]);
    }
    
    /**
     * Test REST API endpoint registration
     */
    public function test_rest_api_endpoints(): void {
        \$routes = rest_get_server()->get_routes();
        
        \$this->assertArrayHasKey('/$plugin_name/v1/items', \$routes);
        \$this->assertArrayHasKey('/$plugin_name/v1/items/(?P<id>\\\\d+)', \$routes);
    }
    
    /**
     * Test GET items endpoint
     */
    public function test_get_items_endpoint(): void {
        wp_set_current_user(\$this->user_id);
        
        \$request = new WP_REST_Request('GET', '/$plugin_name/v1/items');
        \$response = rest_get_server()->dispatch(\$request);
        
        \$this->assertEquals(200, \$response->get_status());
        \$data = \$response->get_data();
        
        \$this->assertIsArray(\$data);
        \$this->assertArrayHasKey('items', \$data);
        \$this->assertArrayHasKey('total', \$data);
    }
    
    /**
     * Test POST items endpoint
     */
    public function test_create_item_endpoint(): void {
        wp_set_current_user(\$this->user_id);
        
        \$request = new WP_REST_Request('POST', '/$plugin_name/v1/items');
        \$request->set_body_params([
            'title' => 'Test Item',
            'content' => 'Test content for the item',
        ]);
        
        \$response = rest_get_server()->dispatch(\$request);
        
        \$this->assertEquals(201, \$response->get_status());
        \$data = \$response->get_data();
        
        \$this->assertArrayHasKey('id', \$data);
    }
    
    /**
     * Test unauthorized access
     */
    public function test_unauthorized_access(): void {
        \$request = new WP_REST_Request('POST', '/$plugin_name/v1/items');
        \$request->set_body_params([
            'title' => 'Test Item',
            'content' => 'Test content',
        ]);
        
        \$response = rest_get_server()->dispatch(\$request);
        
        \$this->assertEquals(401, \$response->get_status());
    }
}
EOF

    # Jest configuration for JavaScript tests
    cat > jest.config.js << 'EOF'
module.exports = {
    testEnvironment: 'jsdom',
    setupFilesAfterEnv: ['<rootDir>/tests/js/setup.js'],
    testMatch: [
        '<rootDir>/tests/js/**/*.test.js'
    ],
    collectCoverageFrom: [
        'assets/js/**/*.js',
        'src/blocks/**/*.js',
        '!**/node_modules/**'
    ],
    coverageDirectory: 'coverage/js',
    coverageReporters: ['html', 'text', 'lcov'],
    moduleNameMapping: {
        '^@/(.*)$': '<rootDir>/assets/js/$1'
    }
};
EOF

    # JavaScript test setup
    mkdir -p tests/js
    cat > tests/js/setup.js << 'EOF'
import '@testing-library/jest-dom';

// Mock WordPress globals
global.wp = {
    blocks: {
        registerBlockType: jest.fn(),
    },
    element: {
        createElement: jest.fn(),
    },
    i18n: {
        __: jest.fn((text) => text),
    },
    blockEditor: {
        useBlockProps: jest.fn(() => ({})),
        RichText: jest.fn(),
        InspectorControls: jest.fn(),
        BlockControls: jest.fn(),
        AlignmentToolbar: jest.fn(),
    },
    components: {
        PanelBody: jest.fn(),
        TextControl: jest.fn(),
    },
};

// Mock jQuery
global.$ = global.jQuery = jest.fn(() => ({
    on: jest.fn(),
    off: jest.fn(),
    addClass: jest.fn(),
    removeClass: jest.fn(),
    attr: jest.fn(),
    data: jest.fn(),
    each: jest.fn(),
    fadeOut: jest.fn(),
    remove: jest.fn(),
}));

// Mock fetch
global.fetch = jest.fn();

// Mock console methods in tests
global.console = {
    ...console,
    warn: jest.fn(),
    error: jest.fn(),
};
EOF

    # JavaScript test example
    cat > tests/js/admin.test.js << 'EOF'
/**
 * Admin JavaScript tests
 */

import { screen, fireEvent, waitFor } from '@testing-library/dom';

// Mock the admin object
global.pluginAdmin = {
    ajaxUrl: 'http://example.com/wp-admin/admin-ajax.php',
    nonce: 'test-nonce',
    strings: {
        saved: 'Settings saved successfully!',
        error: 'An error occurred. Please try again.',
    },
};

describe('Plugin Admin', () => {
    beforeEach(() => {
        document.body.innerHTML = `
            <div class="wrap">
                <h1>Plugin Settings</h1>
                <form id="plugin-settings-form">
                    <input type="text" name="test-setting" value="test" />
                    <button type="submit">Save</button>
                </form>
                <div class="spinner"></div>
            </div>
        `;
        
        // Reset mocks
        global.fetch.mockClear();
        global.$.mockClear();
    });

    test('form submission triggers AJAX request', async () => {
        // Mock successful response
        global.fetch.mockResolvedValueOnce({
            ok: true,
            json: async () => ({ success: true }),
        });

        const form = document.getElementById('plugin-settings-form');
        const submitButton = form.querySelector('button[type="submit"]');

        fireEvent.click(submitButton);

        await waitFor(() => {
            expect(global.fetch).toHaveBeenCalledWith(
                'http://example.com/wp-admin/admin-ajax.php',
                expect.objectContaining({
                    method: 'POST',
                })
            );
        });
    });

    test('spinner shows during form submission', () => {
        const spinner = document.querySelector('.spinner');
        const form = document.getElementById('plugin-settings-form');
        
        fireEvent.submit(form);
        
        expect(spinner.classList.contains('is-active')).toBe(true);
    });
});
EOF

    # Playwright configuration for E2E tests
    cat > playwright.config.js << 'EOF'
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    workers: process.env.CI ? 1 : undefined,
    reporter: 'html',
    use: {
        baseURL: 'http://localhost:8080',
        trace: 'on-first-retry',
    },
    projects: [
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] },
        },
        {
            name: 'firefox',
            use: { ...devices['Desktop Firefox'] },
        },
    ],
    webServer: {
        command: 'docker-compose up -d',
        port: 8080,
        reuseExistingServer: !process.env.CI,
    },
});
EOF

    # E2E test example
    mkdir -p tests/e2e
    cat > tests/e2e/admin.spec.js << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Plugin Admin', () => {
    test.beforeEach(async ({ page }) => {
        // Login to WordPress admin
        await page.goto('/wp-admin');
        await page.fill('#user_login', 'admin');
        await page.fill('#user_pass', 'admin');
        await page.click('#wp-submit');
    });

    test('can access plugin settings page', async ({ page }) => {
        await page.goto('/wp-admin/options-general.php?page=PLUGIN_NAME-settings');
        
        await expect(page.locator('h1')).toContainText('Plugin Settings');
        await expect(page.locator('#plugin-settings-form')).toBeVisible();
    });

    test('can save plugin settings', async ({ page }) => {
        await page.goto('/wp-admin/options-general.php?page=PLUGIN_NAME-settings');
        
        await page.fill('input[name="test-setting"]', 'new value');
        await page.click('button[type="submit"]');
        
        await expect(page.locator('.notice-success')).toBeVisible();
        await expect(page.locator('.notice-success')).toContainText('Settings saved successfully');
    });

    test('can create new item via admin interface', async ({ page }) => {
        await page.goto('/wp-admin/admin.php?page=PLUGIN_NAME-items');
        
        await page.click('text=Add New');
        await page.fill('#item-title', 'Test Item');
        await page.fill('#item-content', 'Test content for the item');
        await page.click('#publish');
        
        await expect(page.locator('.notice-success')).toBeVisible();
        await expect(page.locator('.notice-success')).toContainText('Item created successfully');
    });
});
EOF
}

# Create development workflow files
create_development_workflow() {
    local plugin_name="$1"
    
    # Enhanced development helper script
    cat > wp-dev.sh << EOF
#!/bin/bash
# Enhanced WordPress Development Helper

PLUGIN_NAME="$plugin_name"
PROJECT_DIR="\$(pwd)"

# Colors
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m'

log_info() { echo -e "\${BLUE}ℹ️  \$1\${NC}"; }
log_success() { echo -e "\${GREEN}✅ \$1\${NC}"; }
log_warning() { echo -e "\${YELLOW}⚠️  \$1\${NC}"; }
log_error() { echo -e "\${RED}❌ \$1\${NC}"; }

# Start development environment
start() {
    log_info "Starting WordPress development environment for: \$PLUGIN_NAME"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Start containers
    docker-compose up -d
    
    # Wait for WordPress to be ready
    log_info "Waiting for WordPress to be ready..."
    sleep 30
    
    # Install WordPress if not already installed
    if docker-compose run --rm wp-cli wp core is-installed >/dev/null 2>&1; then
        log_info "WordPress is already installed"
    else
        log_info "Installing WordPress..."
        docker-compose run --rm wp-cli wp core install \\
            --url=http://localhost:8080 \\
            --title="WordPress Development" \\
            --admin_user=admin \\
            --admin_password=admin \\
            --admin_email=admin@localhost.dev
    fi
    
    # Activate plugin
    log_info "Activating plugin: \$PLUGIN_NAME"
    docker-compose run --rm wp-cli wp plugin activate "\$PLUGIN_NAME"
    
    # Install development dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        log_info "Installing Node.js dependencies..."
        npm install
    fi
    
    if [[ ! -d "vendor" ]]; then
        log_info "Installing Composer dependencies..."
        composer install
    fi
    
    # Build assets
    log_info "Building assets..."
    npm run build
    
    log_success "WordPress development environment ready!"
    echo
    echo "🌐 WordPress: http://localhost:8080"
    echo "👤 Admin: http://localhost:8080/wp-admin (admin/admin)"
    echo "🗄️  phpMyAdmin: http://localhost:8081"
    echo "📊 MailHog: http://localhost:8025"
    echo
    echo "💡 Next steps:"
    echo "  • Start asset watcher: npm run dev"
    echo "  • Run tests: npm test"
    echo "  • Run quality checks: warp quality"
    echo "  • View logs: ./wp-dev.sh logs"
}

# Stop development environment
stop() {
    log_info "Stopping WordPress development environment..."
    docker-compose down
    log_success "Environment stopped"
}

# Restart development environment
restart() {
    log_info "Restarting WordPress development environment..."
    stop
    start
}

# View logs
logs() {
    local service="\${1:-wordpress}"
    log_info "Showing logs for: \$service"
    docker-compose logs -f "\$service"
}

# Run WP-CLI commands
wp() {
    docker-compose run --rm wp-cli wp "\$@"
}

# Database operations
db() {
    case "\$1" in
        "backup")
            log_info "Creating database backup..."
            docker-compose run --rm wp-cli wp db export - > "backup-\$(date +%Y%m%d-%H%M%S).sql"
            log_success "Database backup created"
            ;;
        "import")
            if [[ -z "\$2" ]]; then
                log_error "Usage: ./wp-dev.sh db import <backup-file>"
                exit 1
            fi
            log_info "Importing database from: \$2"
            docker-compose run --rm wp-cli wp db import - < "\$2"
            log_success "Database imported"
            ;;
        "reset")
            log_warning "This will reset the entire database. Are you sure? (y/N)"
            read -r confirm
            if [[ "\$confirm" == "y" ]] || [[ "\$confirm" == "Y" ]]; then
                docker-compose run --rm wp-cli wp db reset --yes
                log_success "Database reset"
                start  # Reinstall WordPress
            fi
            ;;
        *)
            echo "Database operations:"
            echo "  backup  - Create database backup"
            echo "  import  - Import database from backup"
            echo "  reset   - Reset database (WARNING: destructive)"
            ;;
    esac
}

# Development tools
dev() {
    case "\$1" in
        "watch")
            log_info "Starting asset watcher..."
            npm run dev
            ;;
        "build")
            log_info "Building assets for production..."
            npm run build
            ;;
        "test")
            log_info "Running all tests..."
            composer test
            npm test
            npm run test:e2e
            ;;
        "lint")
            log_info "Running linters..."
            npm run lint:js
            npm run lint:css
            composer cs
            ;;
        "fix")
            log_info "Fixing code style issues..."
            npm run format:js
            composer cbf
            ;;
        "translate")
            log_info "Generating translation files..."
            npm run translate
            ;;
        *)
            echo "Development tools:"
            echo "  watch     - Watch and rebuild assets"
            echo "  build     - Build assets for production"
            echo "  test      - Run all tests"
            echo "  lint      - Run all linters"
            echo "  fix       - Fix code style issues"
            echo "  translate - Generate translation files"
            ;;
    esac
}

# Quality and security checks
quality() {
    log_info "Running quality checks..."
    warp quality
}

security() {
    log_info "Running security checks..."
    warp security
}

# Plugin management
plugin() {
    case "$1" in
        "activate")
            log_info "Activating plugin: $PLUGIN_NAME"
            docker-compose run --rm wp-cli wp plugin activate "$PLUGIN_NAME"
            ;;
        "deactivate")
            log_info "Deactivating plugin: $PLUGIN_NAME"
            docker-compose run --rm wp-cli wp plugin deactivate "$PLUGIN_NAME"
            ;;
        "status")
            docker-compose run --rm wp-cli wp plugin status "$PLUGIN_NAME"
            ;;
        "install")
            if [[ -z "$2" ]]; then
                log_error "Usage: ./wp-dev.sh plugin install <plugin-name>"
                exit 1
            fi
            log_info "Installing plugin: $2"
            docker-compose run --rm wp-cli wp plugin install "$2" --activate
            ;;
        "uninstall")
            if [[ -z "$2" ]]; then
                log_error "Usage: ./wp-dev.sh plugin uninstall <plugin-name>"
                exit 1
            fi
            log_warning "This will permanently delete plugin: $2. Are you sure? (y/N)"
            read -r confirm
            if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
                docker-compose run --rm wp-cli wp plugin deactivate "$2"
                docker-compose run --rm wp-cli wp plugin uninstall "$2"
                log_success "Plugin uninstalled: $2"
            fi
            ;;
        *)
            echo "Plugin management:"
            echo "  activate    - Activate this plugin"
            echo "  deactivate  - Deactivate this plugin"
            echo "  status      - Show plugin status"
            echo "  install     - Install and activate a plugin"
            echo "  uninstall   - Uninstall a plugin"
            ;;
    esac
}

# Theme management
theme() {
    case "$1" in
        "list")
            docker-compose run --rm wp-cli wp theme list
            ;;
        "activate")
            if [[ -z "$2" ]]; then
                log_error "Usage: ./wp-dev.sh theme activate <theme-name>"
                exit 1
            fi
            log_info "Activating theme: $2"
            docker-compose run --rm wp-cli wp theme activate "$2"
            ;;
        "install")
            if [[ -z "$2" ]]; then
                log_error "Usage: ./wp-dev.sh theme install <theme-name>"
                exit 1
            fi
            log_info "Installing theme: $2"
            docker-compose run --rm wp-cli wp theme install "$2" --activate
            ;;
        *)
            echo "Theme management:"
            echo "  list      - List installed themes"
            echo "  activate  - Activate a theme"
            echo "  install   - Install and activate a theme"
            ;;
    esac
}

# Environment status
status() {
    log_info "WordPress Development Environment Status"
    echo
    
    # Container status
    echo "Docker Containers:"
    docker-compose ps
    echo
    
    # WordPress status
    if docker-compose run --rm wp-cli wp core is-installed >/dev/null 2>&1; then
        echo "✅ WordPress: Installed"
        echo "📊 Version: $(docker-compose run --rm wp-cli wp core version --quiet 2>/dev/null)"
    else
        echo "❌ WordPress: Not installed"
    fi
    
    # Plugin status
    if docker-compose run --rm wp-cli wp plugin is-active "$PLUGIN_NAME" >/dev/null 2>&1; then
        echo "✅ Plugin ($PLUGIN_NAME): Active"
    else
        echo "❌ Plugin ($PLUGIN_NAME): Inactive"
    fi
    
    # Dependencies
    if [[ -d "node_modules" ]]; then
        echo "✅ Node.js dependencies: Installed"
    else
        echo "❌ Node.js dependencies: Not installed (run: npm install)"
    fi
    
    if [[ -d "vendor" ]]; then
        echo "✅ Composer dependencies: Installed"
    else
        echo "❌ Composer dependencies: Not installed (run: composer install)"
    fi
    
    # Assets
    if [[ -d "build" ]]; then
        echo "✅ Built assets: Available"
    else
        echo "❌ Built assets: Not built (run: npm run build)"
    fi
}

# Cleanup development environment
clean() {
    log_warning "This will remove all containers, volumes, and built assets. Are you sure? (y/N)"
    read -r confirm
    if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
        log_info "Cleaning up development environment..."
        
        # Stop and remove containers
        docker-compose down -v --remove-orphans
        
        # Remove built assets
        rm -rf build/
        rm -rf node_modules/.cache/
        
        # Remove coverage reports
        rm -rf coverage/
        
        log_success "Environment cleaned up"
    fi
}

# Setup development environment from scratch
setup() {
    log_info "Setting up WordPress development environment from scratch..."
    
    # Install dependencies
    if command -v npm >/dev/null 2>&1; then
        log_info "Installing Node.js dependencies..."
        npm install
    else
        log_error "npm not found. Please install Node.js first."
        exit 1
    fi
    
    if command -v composer >/dev/null 2>&1; then
        log_info "Installing Composer dependencies..."
        composer install
    else
        log_warning "Composer not found. PHP dependencies will not be installed."
    fi
    
    # Start environment
    start
    
    log_success "Development environment setup complete!"
}

# Main command dispatcher
main() {
    case "$1" in
        "start"|"up")
            start
            ;;
        "stop"|"down")
            stop
            ;;
        "restart")
            restart
            ;;
        "logs")
            shift
            logs "$@"
            ;;
        "wp")
            shift
            wp "$@"
            ;;
        "db")
            shift
            db "$@"
            ;;
        "dev")
            shift
            dev "$@"
            ;;
        "quality")
            quality
            ;;
        "security")
            security
            ;;
        "plugin")
            shift
            plugin "$@"
            ;;
        "theme")
            shift
            theme "$@"
            ;;
        "status")
            status
            ;;
        "clean")
            clean
            ;;
        "setup")
            setup
            ;;
        *)
            echo "WordPress Development Helper for: $PLUGIN_NAME"
            echo "Usage: ./wp-dev.sh <command> [options]"
            echo
            echo "Environment:"
            echo "  start, up     - Start development environment"
            echo "  stop, down    - Stop development environment"
            echo "  restart       - Restart development environment"
            echo "  status        - Show environment status"
            echo "  setup         - Setup environment from scratch"
            echo "  clean         - Clean up environment"
            echo
            echo "WordPress:"
            echo "  wp <cmd>      - Run WP-CLI command"
            echo "  logs [svc]    - View container logs"
            echo "  plugin        - Plugin management"
            echo "  theme         - Theme management"
            echo
            echo "Database:"
            echo "  db backup     - Create database backup"
            echo "  db import     - Import database backup"
            echo "  db reset      - Reset database"
            echo
            echo "Development:"
            echo "  dev watch     - Watch and rebuild assets"
            echo "  dev build     - Build assets for production"
            echo "  dev test      - Run all tests"
            echo "  dev lint      - Run linters"
            echo "  dev fix       - Fix code style"
            echo "  quality       - Run quality checks"
            echo "  security      - Run security checks"
            echo
            echo "Examples:"
            echo "  ./wp-dev.sh start"
            echo "  ./wp-dev.sh wp plugin list"
            echo "  ./wp-dev.sh dev watch"
            echo "  ./wp-dev.sh db backup"
            ;;
    esac
}

main "$@"
EOF

    chmod +x wp-dev.sh
    
    # Enhanced Docker Compose with additional services
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  wordpress:
    image: wordpress:php8.2-apache
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DEBUG: 1
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_DEBUG', true);
        define('WP_DEBUG_LOG', true);
        define('WP_DEBUG_DISPLAY', false);
        define('SCRIPT_DEBUG', true);
        define('WP_ENVIRONMENT_TYPE', 'local');
        
        // Plugin development
        define('WP_AUTO_UPDATE_CORE', false);
        define('AUTOMATIC_UPDATER_DISABLED', true);
        
        // Memory and execution limits
        ini_set('memory_limit', '512M');
        ini_set('max_execution_time', 300);
        ini_set('max_input_vars', 3000);
        
        // Error reporting
        ini_set('display_errors', 1);
        ini_set('display_startup_errors', 1);
        error_reporting(E_ALL);
        
        // Mail configuration (use MailHog)
        ini_set('SMTP', 'mailhog');
        ini_set('smtp_port', 1025);
    volumes:
      - wordpress_data:/var/www/html
      - .:/var/www/html/wp-content/plugins/$plugin_name
      - ./docker/wordpress/wp-config-extra.php:/var/www/html/wp-config-extra.php:ro
      - ./docker/wordpress/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini:ro
    depends_on:
      - db
      - mailhog
    networks:
      - wordpress-network

  db:
    image: mysql:8.0
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
      MYSQL_ROOT_PASSWORD: rootpassword
    volumes:
      - db_data:/var/lib/mysql
      - ./docker/mysql/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
      - ./docker/mysql/my.cnf:/etc/mysql/conf.d/my.cnf:ro
    ports:
      - "3306:3306"
    networks:
      - wordpress-network

  phpmyadmin:
    image: phpmyadmin:latest
    ports:
      - "8081:80"
    environment:
      PMA_HOST: db
      PMA_USER: wordpress
      PMA_PASSWORD: wordpress
      PMA_ARBITRARY: 1
    depends_on:
      - db
    networks:
      - wordpress-network

  wp-cli:
    image: wordpress:cli-php8.2
    user: xfs
    volumes:
      - wordpress_data:/var/www/html
      - .:/var/www/html/wp-content/plugins/$plugin_name
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    depends_on:
      - db
      - wordpress
    networks:
      - wordpress-network

  mailhog:
    image: mailhog/mailhog
    ports:
      - "8025:8025"  # Web interface
      - "1025:1025"  # SMTP server
    networks:
      - wordpress-network

  node:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - .:/app
    command: npm run dev
    profiles:
      - dev

  adminer:
    image: adminer:latest
    ports:
      - "8082:8080"
    environment:
      ADMINER_DEFAULT_SERVER: db
    depends_on:
      - db
    networks:
      - wordpress-network
    profiles:
      - tools

volumes:
  wordpress_data:
  db_data:

networks:
  wordpress-network:
    driver: bridge
EOF

    # Docker configuration files
    mkdir -p docker/{wordpress,mysql}
    
    # WordPress configuration
    cat > docker/wordpress/uploads.ini << 'EOF'
upload_max_filesize = 50M
post_max_size = 50M
max_execution_time = 300
max_input_vars = 3000
memory_limit = 512M
EOF

    cat > docker/wordpress/wp-config-extra.php << 'EOF'
<?php
/**
 * Additional WordPress configuration for development
 */

// Plugin development helpers
if (!defined('WP_DEBUG_LOG')) {
    define('WP_DEBUG_LOG', true);
}

// Enable debug logging for our plugin
if (!function_exists('write_log')) {
    function write_log($log) {
        if (true === WP_DEBUG) {
            if (is_array($log) || is_object($log)) {
                error_log(print_r($log, true));
            } else {
                error_log($log);
            }
        }
    }
}

// Development helper functions
if (!function_exists('dd')) {
    function dd($data) {
        echo '<pre>';
        var_dump($data);
        echo '</pre>';
        die();
    }
}
EOF

    # MySQL configuration
    cat > docker/mysql/my.cnf << 'EOF'
[mysql]
default-character-set = utf8mb4

[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
max_allowed_packet = 256M
innodb_log_file_size = 256M
innodb_buffer_pool_size = 256M
EOF

    cat > docker/mysql/init.sql << 'EOF'
-- Development database initialization
CREATE DATABASE IF NOT EXISTS wordpress_test;
GRANT ALL PRIVILEGES ON wordpress_test.* TO 'wordpress'@'%';

-- Create additional development users
CREATE USER IF NOT EXISTS 'dev'@'%' IDENTIFIED BY 'dev';
GRANT ALL PRIVILEGES ON wordpress.* TO 'dev'@'%';
GRANT ALL PRIVILEGES ON wordpress_test.* TO 'dev'@'%';

FLUSH PRIVILEGES;
EOF

    # GitHub Actions workflow for WordPress plugin
    mkdir -p .github/workflows
    cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        php: ['8.0', '8.1', '8.2']
        wordpress: ['6.0', '6.1', '6.2', '6.3', '6.4']
        
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_DATABASE: wordpress_test
          MYSQL_USER: wordpress
          MYSQL_PASSWORD: wordpress
          MYSQL_ROOT_PASSWORD: root
        ports:
          - 3306:3306
        options: --health-cmd="mysqladmin ping" --health-interval=10s --health-timeout=5s --health-retries=3

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: ${{ matrix.php }}
        extensions: mysql, zip, gd, mbstring, curl, xml, bcmath
        tools: composer, phpcs, phpstan, phpunit
        coverage: xdebug

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'

    - name: Install PHP dependencies
      run: composer install --no-progress --no-interaction --prefer-dist --optimize-autoloader

    - name: Install Node dependencies
      run: npm ci

    - name: Build assets
      run: npm run build

    - name: Setup WordPress test environment
      run: |
        bash bin/install-wp-tests.sh wordpress_test wordpress wordpress localhost ${{ matrix.wordpress }}

    - name: Run PHP tests
      run: |
        phpunit --coverage-clover=coverage/clover.xml
      env:
        WP_TESTS_DIR: /tmp/wordpress-tests-lib
        WP_CORE_DIR: /tmp/wordpress/

    - name: Run JavaScript tests
      run: npm test -- --coverage

    - name: Run E2E tests
      run: |
        docker-compose up -d
        sleep 30
        npm run test:e2e
      
    - name: PHP Code Standards
      run: phpcs --standard=WordPress --runtime-set ignore_errors_on_exit 1 --runtime-set ignore_warnings_on_exit 1

    - name: PHPStan Analysis
      run: phpstan analyse --memory-limit=1G

    - name: JavaScript Lint
      run: npm run lint:js

    - name: CSS Lint
      run: npm run lint:css

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage/clover.xml,./coverage/lcov.info
        flags: unittests
        name: codecov-umbrella

  security:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run Warp Security Check
      run: |
        # Install Warp (this would be from actual repository)
        curl -sSL https://raw.githubusercontent.com/user/warp/main/install.sh | bash
        warp security

    - name: Security Audit (PHP)
      run: |
        if [ -f composer.lock ]; then
          composer audit
        fi

    - name: Security Audit (Node)
      run: |
        if [ -f package-lock.json ]; then
          npm audit --audit-level moderate
        fi

  deploy:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'

    - name: Install dependencies and build
      run: |
        npm ci
        npm run build

    - name: Create release archive
      run: |
        # Create clean archive for WordPress.org
        mkdir -p release/PLUGIN_NAME
        
        # Copy plugin files (exclude development files)
        rsync -av --exclude-from='.distignore' . release/PLUGIN_NAME/
        
        # Create ZIP file
        cd release
        zip -r PLUGIN_NAME.zip PLUGIN_NAME/

    - name: Upload release artifact
      uses: actions/upload-artifact@v3
      with:
        name: plugin-release
        path: release/PLUGIN_NAME.zip
EOF

    # .distignore file for clean releases
    cat > .distignore << 'EOF'
/.git
/.github
/node_modules
/vendor
/tests
/docker
/.vscode
/.idea

# Development files
webpack.config.js
jest.config.js
playwright.config.js
phpunit.xml
composer.json
composer.lock
package.json
package-lock.json
wp-dev.sh

# Source files
/assets/scss
/assets/js
/src/blocks
*.map

# Test and coverage files
/coverage
/.phpunit.cache
/.nyc_output

# Config files
.eslintrc*
.prettierrc*
.stylelintrc*
phpcs.xml
phpstan.neon
.editorconfig
.gitignore
.distignore

# Documentation
README.md
CHANGELOG.md
CONTRIBUTING.md

# Logs
*.log
EOF

    log_success "Advanced WordPress development environment created!"
    echo
    echo "🎯 Features included:"
    echo "  • Modern PHP with namespaces and autoloading"
    echo "  • Gutenberg block development with @wordpress/scripts"
    echo "  • SCSS compilation and JavaScript bundling"
    echo "  • PHPUnit, Jest, and Playwright testing"
    echo "  • WordPress Coding Standards (PHPCS/WPCS)"
    echo "  • REST API with proper authentication"
    echo "  • Docker development environment"
    echo "  • MailHog for email testing"
    echo "  • Complete CI/CD pipeline"
    echo "  • Development helper scripts"
    echo
    echo "🚀 Quick start:"
    echo "  1. Install dependencies: npm install && composer install"
    echo "  2. Start environment: ./wp-dev.sh start"
    echo "  3. Start asset watcher: ./wp-dev.sh dev watch"
    echo "  4. Open WordPress: http://localhost:8080"
}

# Main function handler
main() {
    case "$1" in
        "plugin")
            shift
            local plugin_name="$1"
            local description="${2:-WordPress plugin created with Warp}"
            
            if [[ -z "$plugin_name" ]]; then
                log_error "Plugin name is required"
                echo "Usage: warp wordpress plugin <name> [description]"
                exit 1
            fi
            
            create_modern_wp_plugin "$plugin_name" "$description"
            ;;
        *)
            echo "Advanced WordPress Development"
            echo "Usage: warp wordpress plugin <name> [description]"
            echo
            echo "Creates a modern WordPress plugin with:"
            echo "  • PHP 8+ with namespaces and autoloading"
            echo "  • Modern JavaScript build system"
            echo "  • Gutenberg block development"
            echo "  • Complete testing suite"
            echo "  • Docker development environment"
            echo "  • CI/CD pipeline"
            echo
            echo "Example:"
            echo "  warp wordpress plugin my-awesome-plugin 'An awesome WordPress plugin'"
            ;;
    esac
}

main "$@"
