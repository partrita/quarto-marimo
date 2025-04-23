-- utils
function is_mime_sensitive()
    -- Determine whether we can render the html tags that island produces. If
    -- not, this flag will let's us directly output a representative value.
    local output_file = PANDOC_STATE.output_file
    return string.match(output_file, "%.pdf$")
        or string.match(output_file, "%.tex$")
end

local stringify = pandoc.utils.stringify

function concat_lists(...)
    local result = {}
    for i = 1, select("#", ...) do
        local t = select(i, ...)
        for j = 1, #t do
            result[#result + 1] = t[j]
        end
    end
    return result
end

-- Function to extract text from a Pandoc Para object
local function extract_text_from_para(para)
    local text = ""
    for _, el in ipairs(para) do
        if el.t == "Str" then
            text = text .. el.text -- Add the string content
        elseif el.t == "Space" then
            text = text .. " " -- Add space
        elseif el.t == "SoftBreak" then
            text = text .. "\n" -- Add newline for SoftBreak
        elseif el.t == "Quoted" then
            -- Handle Quoted elements, extract the inner string
            for _, q_el in ipairs(el.content) do
                if q_el.t == "Str" then
                    text = text .. '"' .. q_el.text .. '"'
                end
            end
        end
    end
    return text
end

local function _parse_header_metadata(header_str)
    local lines = {}
    for line in header_str:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local in_block = false
    local deps = { python_version = "3.10", dependencies = {} }
    local dep_block = false

    for _, l in ipairs(lines) do
        if l:match("^%s*///") then
            if not in_block then
                in_block = true
            else
                break
            end
        elseif in_block then
            -- strip leading "#"
            local content = l:gsub("^%s*", "")
            -- python version
            local pv = content:match('^requires%-python%s*=%s*"(.-)"')
            if pv then
                deps.python_version = pv
            -- start dependencies block
            elseif content:match("^dependencies%s*=%s*%[") then
                dep_block = true
            elseif dep_block then
                -- end of list
                if content:match("%]") then
                    dep_block = false
                end
                -- extract any quoted strings
                for pkg in content:gmatch('"([^"]+)"') do
                    table.insert(deps.dependencies, pkg)
                end
            end
        end
    end

    return deps
end

-- Deduplicate and normalize sandbox dependencies,
-- always include marimo@version and any feature‑specific packages.
local function _normalize_sandbox_dependencies(deps, version)
    local seen, out = {}, {}
    for _, d in ipairs(deps or {}) do
        if not seen[d] then
            seen[d] = true
            table.insert(out, d)
        end
    end
    local marimo_dep = "marimo==" .. version
    if not seen[marimo_dep] then
        table.insert(out, marimo_dep)
        seen[marimo_dep] = true
    end
    return out
end

-- Construct the full UV command given:
function _construct_uv_command(meta)
    --[[
    -- TODO: Consider just calling from marimo.
    --]]
    local version = stringify(meta["marimo-version"] or "0.13.0")
    local deps = _parse_header_metadata(
        extract_text_from_para(meta["sandbox"][1].content)
    )
    local uv_needs_refresh = (#deps == 0)

    local deps = _normalize_sandbox_dependencies(deps.dependencies, version)

    local req_file = os.tmpname() .. ".txt"
    do
        local f = assert(io.open(req_file, "w"))
        f:write(table.concat(deps, "\n"))
        f:close()
    end

    local uv_cmd = {
        "run",
        "--isolated",
        "--no-project",
        "--compile-bytecode",
        "--with-requirements",
        req_file,
    }
    if uv_needs_refresh then
        table.insert(uv_cmd, "--refresh")
    end
    if python_version then
        table.insert(uv_cmd, "--python")
        table.insert(uv_cmd, python_version)
    end

    return uv_cmd
end

function run_marimo(meta)
    local file_path = debug.getinfo(1, "S").source:sub(2)
    local file_dir = file_path:match("(.*[/\\])")
    local endpoint_script = file_dir .. "extract.py"

    -- PDFs / LaTeX have to be handled specifically for mimetypes
    -- Need to pass in a string as arg in python invocation.
    local mime_sensitive = "no"
    if is_mime_sensitive(doc) then
        mime_sensitive = "yes"
    end

    local command = endpoint_script
    local args = {}
    if meta["sandbox"] ~= nil then
        command = "uv"
        args = concat_lists(_construct_uv_command(meta), { endpoint_script })
    end

    local parsed_data = {}
    local result = {}
    for _, filename in ipairs(PANDOC_STATE.input_files) do
        local input_file = io.open(filename, "r")
        if input_file then
            local text = input_file:read("*all")
            input_file:close()

            text = text or ""

            -- Parse the input file using the external Python script
            default_args = { filename, mime_sensitive }
            result = pandoc.json.decode(
                pandoc.pipe(command, concat_lists(args, default_args), text)
            )
            -- Concatenate the result arrays
            for _, item in ipairs(result["outputs"]) do
                table.insert(parsed_data, item)
            end
        end
    end
    result["outputs"] = parsed_data
    return result
end

return {
    is_mime_sensitive = is_mime_sensitive,
    run_marimo = run_marimo,
}
