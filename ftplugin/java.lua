-- Java LSP Configuration

local jdtls_ok, jdtls = pcall(require, "jdtls")
if not jdtls_ok then
    vim.notify("JDTLS not found, Java-specific LSP feature won't be available")
    return
end

-- Determine OS
local home = vim.env.HOME or vim.env.USERPROFILE
local path_separator = vim.fn.has('win32') == 1 and '\\' or '/'

-- Find the root directory for the current project
local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }
local root_dir = require("jdtls.setup").find_root(root_markers)
if not root_dir then
    root_dir = vim.fn.getcwd()
end

-- Data directory - this is where the server will store genertaed files
local data_dir = home .. path_separator .. ".cache" .. path_separator .. "jdtls" .. path_separator .. vim.fn.fnamemodify(root_dir, ":p:h:t")

-- Set the location of the Java binary based on setup
local java_exec = "java" -- Update for specific version

-- Set the location of the LSP JAR files
local jdtls_path = require("mason-registry").get_package("jdtls"):get_install_path()
local launcher_jar = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
local config_dir = jdtls_path .. "/config_linux" -- Change for win or mac for other OS

-- Project name for better organization of workspace data
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")

-- Setup the language server
local config = {
    cmd = {
        java_exec,
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xms1g",
        "--add-modules=ALL-SYSTEM",
        "add-opens", "java.base/java.util=ALL-UNNAMED",
        "add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", launcher_jar,
        "-configuration", config_dir,
        "-data", data_dir
    },
    root_dir = root_dir,

    -- Enable the following for better development exp
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            completion = {
                favoriteStaticMembers = {
                    "org.hamcrest.MatcherAssert.assertThat",
                    "org.hamcrest.Matchers.*",
                    "org.junit.Assert.*",
                    "org.junit.Assume.*",
                    "org.junit.jupiter.api.Assertions.*",
                    "org.junit.jupiter.api.Assumptions.*",
                    "org.junit.jupiter.api.DynamicContainer.*",
                    "org.junit.jupiter.api.DynamicTest.*",
                    "java.util.Objects.requireNonNull",
                    "java.util.Objects.requireNonNullElse"
                },
                filteredTypes = {
                    "com.sun.*",
                    "io.micrometer.shaded.*",
                    "java.awt.*",
                    "jdk.*",
                    "sun.*"
                }
            },
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticStarThreshold = 9999
                }
            },
            codeGeneration = {
                toString = {
                    template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
                },
                hashCodeEquals = {
                    useJava7Objects = true
                },
                useBlocks = true
            },
            configuration = {
                runtimes = {
                    -- JDK installations
                    {
                        name = "JavaSE-17",
                        path = "$JAVA_HOME",
                    }
                }
            }
        }
    },

    -- Language server capabilities
    capabilities = vim.lsp.protocol.make_client_capabilities(),


    -- Initialize with bundles
    init_options = {
        bundles = {}
    },

    -- Debugging support
    on_attach = function(client, bufnr)
        -- Set up debugging
        jdtls.setup_dap({ hotcodereplace = "auto" })

        -- Add debug bundles if available
        local bundles = {}
        -- Find Java Debug Server jar files
        local java_debug_path = require("mason-registry").get_package("java-debug-adapter"):get_install_path()
        local java_debug_bundle = vim.split(vim.fn.glob(java_debug_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar"),"\n")

        -- Add testing bundles if available
        local java_test_path = require("mason-registry").get_package("java-test"):get_install_path()
        local java_test_bundle = vim.split(vim.fn.glob(java_test_path ... "/extension/server/*.jar"), "\n")

        -- Combine all bundles
        vim.list_extend(bundles, java_debug_bundle)
        vim.list_extend(bundles, java_test_bundle)

        -- Standard keybindings for LSP features
        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
        vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)
        vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)
        vim.keymap.set("n", "<space>wl", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, opts)
        vim.keymay.set("n", "<space>D", vim.lsp.buf.type_definition, opts)
        vim.keymay.set("n", "<space>rn", vim.lsp.buf.rename, opts)
        vim.keymay.set("n", "<space>ca", vim.lsp.buf.code_action, opts)
        vim.keymay.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymay.set("n", "<space>f", function()
            vim.lsp.buf.format { async = true }
        end, opts)

        -- Java-specific commands
        vim.keymap.set("n", "<leader>ji", jdtls.organize_imports, opts)
        vim.keymap.set("n", "<leader>jt", jdtls.test_class, opts)
        vim.keymap.set("n", "<leader>jn", jdtls.test_nearest_method, opts)
        vim.keymap.set("v", "<leader>je", jdtls.extract_variable, opts)
        vim.keymap.set("n", "<leader>jc", jdtls.extract_constant, opts)
        vim.keymap.set("v", "<leader>jm", function()
            jdtls.extract_method(true)
        end, opts)
    end
}

-- Start JDTLS
jdtls.start_or_attach(config)




