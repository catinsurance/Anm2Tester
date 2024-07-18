local TextCapture = {}
local endCallback = function ()
    return
end

-- this is code that i originally wrote for Epiphany

-- {lowercase, UPPERCASE}
local validCharacters = {
	[Keyboard.KEY_A] = {"a", "A"},
	[Keyboard.KEY_B] = {"b", "B"},
    [Keyboard.KEY_C] = {"c", "C"},
    [Keyboard.KEY_D] = {"d", "D"},
    [Keyboard.KEY_E] = {"e", "E"},
    [Keyboard.KEY_F] = {"f", "F"},
    [Keyboard.KEY_G] = {"g", "G"},
    [Keyboard.KEY_H] = {"h", "H"},
    [Keyboard.KEY_I] = {"i", "I"},
    [Keyboard.KEY_J] = {"j", "J"},
    [Keyboard.KEY_K] = {"k", "K"},
    [Keyboard.KEY_L] = {"l", "L"},
    [Keyboard.KEY_M] = {"m", "M"},
    [Keyboard.KEY_N] = {"n", "N"},
    [Keyboard.KEY_O] = {"o", "O"},
    [Keyboard.KEY_P] = {"p", "P"},
    [Keyboard.KEY_Q] = {"q", "Q"},
    [Keyboard.KEY_R] = {"r", "R"},
    [Keyboard.KEY_S] = {"s", "S"},
    [Keyboard.KEY_T] = {"t", "T"},
    [Keyboard.KEY_U] = {"u", "U"},
    [Keyboard.KEY_V] = {"v", "V"},
    [Keyboard.KEY_W] = {"w", "W"},
    [Keyboard.KEY_X] = {"x", "X"},
    [Keyboard.KEY_Y] = {"y", "Y"},
    [Keyboard.KEY_Z] = {"z", "Z"},

	[Keyboard.KEY_0] = {"0", ")"},
    [Keyboard.KEY_1] = {"1", "!"},
    [Keyboard.KEY_2] = {"2", "@"},
    [Keyboard.KEY_3] = {"3", "#"},
    [Keyboard.KEY_4] = {"4", "$"},
    [Keyboard.KEY_5] = {"5", "%"},
    [Keyboard.KEY_6] = {"6", "^"},
    [Keyboard.KEY_7] = {"7", "&"},
    [Keyboard.KEY_8] = {"8", "*"},
    [Keyboard.KEY_9] = {"9", "("},

	[Keyboard.KEY_MINUS] = {"-", "_"},
	[Keyboard.KEY_EQUAL] = {"=", "+"},
	[Keyboard.KEY_LEFT_BRACKET] = {"[", "{"},
	[Keyboard.KEY_RIGHT_BRACKET] = {"]", "}"},
	[Keyboard.KEY_SEMICOLON] = {";", ":"},
	[Keyboard.KEY_APOSTROPHE] = {"'", "\""},
	[Keyboard.KEY_COMMA] = {",", "<"},
	[Keyboard.KEY_PERIOD] = {".", ">"},
	[Keyboard.KEY_SLASH] = {"/", "?"},
	[Keyboard.KEY_SPACE] = {" ", " "},
}

function TextCapture:CaptureText(_, hook)
    if hook ~= InputHook.IS_ACTION_PRESSED and hook ~= InputHook.IS_ACTION_TRIGGERED then
        return
    end
    if TextCapture.CapturingText then
        return false
    end
end

function TextCapture:StartInputCapture(dssmod, target, callback)
    dssmod:DisableInput()
    TextCapture.TextCaptureTarget = target
    TextCapture.CapturingTextLine = ""
    TextCapture.CapturingText = true

    if callback then
        endCallback = callback
    end
end

function TextCapture:EndInputCapture(dssmod)
    TextCapture.CapturingText = false
    TextCapture.FinalizedCapturedTextLine = TextCapture.CapturingTextLine
    TextCapture.CapturingTextLine = ""
    TextCapture.TextCaptureTarget = nil

    dssmod:EnableInput()
    endCallback()
end

return function (mod, dssmod)
    function TextCapture:TextCaptureHandler()
        if TextCapture.CapturingText then
            dssmod:DisableInput()
            if TextCapture.CapturingTextLine == " " then -- bandaid fix for the text being set to space when text capture starts
                TextCapture.CapturingTextLine = ""
            end

            for character, str in pairs(validCharacters) do
                if Input.IsButtonTriggered(character, 0) then
                    if Input.IsButtonPressed(Keyboard.KEY_LEFT_SHIFT, 0) or Input.IsButtonPressed(Keyboard.KEY_RIGHT_SHIFT, 0) then
                        TextCapture.CapturingTextLine = TextCapture.CapturingTextLine .. str[2]
                    else
                        TextCapture.CapturingTextLine = TextCapture.CapturingTextLine .. str[1]
                    end
                end
            end

            if Input.IsButtonTriggered(Keyboard.KEY_BACKSPACE, 0) then
                TextCapture.CapturingTextLine = TextCapture.CapturingTextLine:sub(1, TextCapture.CapturingTextLine:len() - 1)
            end

            TextCapture.LastTextCaptureTarget = TextCapture.TextCaptureTarget

            if Input.IsButtonTriggered(Keyboard.KEY_ENTER, 0) or Input.IsButtonTriggered(Keyboard.KEY_ESCAPE, 0) then
                TextCapture:EndInputCapture(dssmod)
            end
        end
    end

    mod:AddCallback(ModCallbacks.MC_POST_RENDER, TextCapture.TextCaptureHandler)

    function TextCapture:CaptureText(_, hook)
        if hook ~= InputHook.IS_ACTION_PRESSED and hook ~= InputHook.IS_ACTION_TRIGGERED then
            return
        end

        if TextCapture.CapturingText then
            return false
        end
    end

    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, TextCapture.CaptureText)

    return TextCapture
end