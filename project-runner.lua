-- lua/project_runner.lua
local M = {}

M.global_config = {}

local function parse_yaml(filepath)
    local config = {}
    local f = io.open(filepath, "r")
    if not f then return config end
    
    for line in f:lines() do
        -- Strip hidden Windows carriage returns (\r)
        line = line:gsub("\r$", "")
        
        if not line:match("^%s*#") and line:match("%S") then
            -- Safely extract key and value
            local key, val = line:match("^%s*([%w_%-]+)%s*:%s*(.*)$")
            if key and val then
                -- Trim trailing whitespace from value
                val = val:gsub("%s+$", "")
                -- Strip surrounding quotes if they exist
                val = val:match("^[\"']?(.-)[\"']?$") or val
                config[key] = val
            end
        end
    end
    f:close()
    return config
end

local function get_project_config()
    local current_dir = vim.fn.expand('%:p:h')
    if current_dir == "" then current_dir = vim.fn.getcwd() end

    -- Look for .yaml, .yml, or fallback to .git
    local root_file = vim.fs.find({'.runner.yaml', '.runner.yml', '.git'}, { upward = true, path = current_dir })[1]
    
    if root_file then
        local root_dir = vim.fn.fnamemodify(root_file, ':h')
        local path_yaml = root_dir .. "/.runner.yaml"
        local path_yml = root_dir .. "/.runner.yml"
        
        if vim.fn.filereadable(path_yaml) == 1 then
            return parse_yaml(path_yaml), path_yaml
        elseif vim.fn.filereadable(path_yml) == 1 then
            return parse_yaml(path_yml), path_yml
        end
    end
    return {}, nil
end

local function prepare_cmd(cmd_template)
    local vars = {
        ["$fileNameWithoutExt"] = vim.fn.expand('%:t:r'),
        ["$fileName"] = vim.fn.expand('%:t'),
        ["$filePath"] = vim.fn.expand('%:p'),
        ["$dir"] = vim.fn.expand('%:p:h'),
    }
    return cmd_template:gsub("%$[%w_]+", function(match)
        return vars[match] or match
    end)
end

function M.setup(opts)
    M.global_config = vim.tbl_deep_extend("force", { mode = "term" }, opts or {})
    
    vim.api.nvim_create_user_command('RunFile', function(args) M.run("file", args.args) end, { nargs = '?' })
    vim.api.nvim_create_user_command('RunProject', function(args) M.run("project", args.args) end, { nargs = '?' })
    
    -- Diagnostic command to debug parsing issues
    vim.api.nvim_create_user_command('RunInfo', M.info, {})
end

function M.info()
    local config, path = get_project_config()
    local msg = "ProjectRunner Diagnostics:\n--------------------------\n"
    
    if path then
        msg = msg .. "YAML Found at: " .. path .. "\n"
        msg = msg .. "Parsed Keys:\n"
        local count = 0
        for k, v in pairs(config) do
            msg = msg .. "  - [" .. k .. "] -> " .. v .. "\n"
            count = count + 1
        end
        if count == 0 then
            msg = msg .. "  (Warning: File was found but no keys were parsed. Check formatting.)\n"
        end
    else
        msg = msg .. "No .runner.yaml or .runner.yml found in parent directories.\n"
    end
    
    vim.notify(msg, vim.log.levels.INFO)
end

function M.run(target, args_mode)
    local project_config, yaml_path = get_project_config()

    local mode = args_mode
    if not mode or mode == "" then 
        mode = project_config.mode or M.global_config.mode 
    end
    mode = mode:gsub("%s+", "")

    local cmd_template
    
    if target == "project" then
        cmd_template = project_config.project or M.global_config.project
        if not cmd_template then
            vim.notify("ProjectRunner: No 'project' key defined in config.", vim.log.levels.WARN)
            return
        end
    else
        local ft = vim.bo.filetype
        cmd_template = project_config[ft] or M.global_config[ft]
        
        if not cmd_template then
            cmd_template = project_config.project or M.global_config.project
        end
        
        if not cmd_template then
            vim.notify("ProjectRunner: No command for '" .. ft .. "' and no 'project' fallback found.", vim.log.levels.WARN)
            return
        end
    end

    vim.cmd('silent! write')
    local cmd = prepare_cmd(cmd_template)

    if mode == "float" then
        local width = math.floor(vim.o.columns * 0.8)
        local height = math.floor(vim.o.lines * 0.8)
        local col = math.floor((vim.o.columns - width) / 2)
        local row = math.floor((vim.o.lines - height) / 2)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            col = col,
            row = row,
            style = "minimal",
            border = "rounded"
        })
        vim.fn.termopen(cmd)
    else
        vim.cmd('botright split')
        vim.cmd('terminal ' .. cmd)
    end
    
    vim.cmd('startinsert')
end

return M
