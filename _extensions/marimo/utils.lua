-- 유틸리티
local stringify = pandoc.utils.stringify
local file_path = debug.getinfo(1, "S").source:sub(2)
local file_dir = file_path:match("(.*[/\\])")

function is_mime_sensitive()
    -- island가 생성하는 html 태그를 렌더링할 수 있는지 확인합니다.
    -- 그렇지 않은 경우 이 플래그를 사용하면 대표 값을 직접 출력할 수 있습니다.
    local output_file = PANDOC_STATE.output_file
    return string.match(output_file, "%.pdf$")
        or string.match(output_file, "%.tex$")
end

-- 루아는 정말 끔찍합니다.
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

-- Pandoc Para 객체에서 텍스트를 추출하는 함수
-- 이것은 깊이 중첩된 모나드입니다.
local function extract_text(para)
    local text = ""
    -- 테이블이 전달되면 해당 요소들을 반복해야 합니다.
    for _, el in ipairs(para) do
        if el.t == "Para" then
            -- 중첩된 Para 요소에서 텍스트를 재귀적으로 추출합니다.
            text = text .. extract_text(el.content)
        elseif el.t == "Str" then
            text = text .. el.text -- 문자열 내용을 추가합니다.
        elseif el.t == "Space" then
            text = text .. " " -- 공백을 추가합니다.
        elseif el.t == "SoftBreak" then
            text = text .. "\n" -- SoftBreak에 대해 줄 바꿈을 추가합니다.
        elseif el.t == "Quoted" then
            -- Quoted 요소를 처리하고 내부 문자열을 추출합니다.
            for _, q_el in ipairs(el.content) do
                if q_el.t == "Str" then
                    text = text .. '"' .. q_el.text .. '"'
                end
            end
        end
    end
    return text
end

-- 주어진 헤더로 전체 UV 명령을 구성합니다:
function _construct_uv_command(header)
    local command_script = file_dir .. "command.py"
    return pandoc.json.decode(
        pandoc.pipe(
            "uv",
            { "run", "--with", "marimo", command_script },
            header
        )
    )
end

function run_marimo(meta)
    local endpoint_script = file_dir .. "extract.py"

    -- PDF / LaTeX는 마임타입에 대해 특별히 처리해야 합니다.
    -- 파이썬 호출에서 인수로 문자열을 전달해야 합니다.
    local mime_sensitive = "no"
    if is_mime_sensitive(doc) then
        mime_sensitive = "yes"
    end

    local command = "uv"
    local args = {}
    if meta["external-env"] ~= nil then
        assert(
            meta["external-env"] == true,
            "external-env 메타 키는 true로 설정하거나 생략해야 합니다."
        )
        assert(
            meta["pyproject"] == nil,
            "external-env를 사용할 때 pyproject 메타 키는 생략해야 합니다."
        )
        args = { "run", endpoint_script }
    elseif meta["pyproject"] ~= nil then
        header = extract_text(meta["pyproject"])
        args = concat_lists(_construct_uv_command(header), { endpoint_script })
    elseif meta["header"] ~= nil then
        header = extract_text(meta["header"])
        args = concat_lists(_construct_uv_command(header), { endpoint_script })
    else
        args = concat_lists(_construct_uv_command(""), { endpoint_script })
    end

    local parsed_data = {}
    local result = {}
    for _, filename in ipairs(PANDOC_STATE.input_files) do
        local input_file = io.open(filename, "r")
        if input_file then
            local text = input_file:read("*all")
            input_file:close()

            text = text or ""

            -- 외부 파이썬 스크립트를 사용하여 입력 파일을 파싱합니다.
            default_args = { filename, mime_sensitive }
            result = pandoc.json.decode(
                pandoc.pipe(command, concat_lists(args, default_args), text)
            )
            -- 결과 배열을 연결합니다.
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
