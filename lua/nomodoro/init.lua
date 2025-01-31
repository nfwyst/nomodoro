-- Check if already loaded
if vim.g.loaded_nomodoro then
  return
end
vim.g.loaded_nomodoro = true

local menu = require('nomodoro.menu')

local command = vim.api.nvim_create_user_command

local start_time = 0
local total_minutes = 0

local DONE = 0
local RUNNING = 1
local PAUSE = 2
local state = DONE

local already_notified_end = false

vim.g.break_count = 0

--- The default options
local DEFAULT_OPTIONS = {
    work_time = 25,
    short_break_time = 5,
    long_break_time = 15,
    break_cycle = 4,
    menu_available = true,
    texts = {
        on_break_complete = "TIME IS UP!",
        on_work_complete = "TIME IS UP!",
        status_icon = "🍅 ",
        timer_format = '!%0M:%0S' -- To include hours: '!%0H:%0M:%0S'
    },
    on_work_complete = function() end,
    on_break_complete = function() end
}

-- Local functions

local previous_time_remaining = nil
local new_start = nil
local function time_remaining_seconds(duration, start)
    if state == PAUSE then
      if not previous_time_remaining then
        previous_time_remaining = duration * 60 - os.difftime(os.time(), new_start or start)
        new_start = nil
      end
      return previous_time_remaining
    end
    if previous_time_remaining and not new_start then
      new_start = os.difftime(os.time(), duration * 60 - previous_time_remaining)
      previous_time_remaining = nil
    end
    return duration * 60 - os.difftime(os.time(), new_start or start)
end

local function time_remaining(duration, start)
    return os.date(vim.g.nomodoro.texts.timer_format, time_remaining_seconds(duration, start))
end

local function is_work_time(duration)
    return duration == vim.g.nomodoro.work_time
end

-- Plugin functions

local nomodoro = {
}

function nomodoro.start(minutes)
    start_time = os.time()
    total_minutes = minutes
    already_notified_end = false
    state = RUNNING
end

function nomodoro.pause()
  state = PAUSE
end

function nomodoro.continue()
  state = RUNNING
end

function nomodoro.is_pause()
  return state == PAUSE
end

function nomodoro.is_running()
  return state == RUNNING
end

function nomodoro.start_break()
    if nomodoro.is_short_break() then
        nomodoro.start(vim.g.nomodoro.short_break_time)
    else
        nomodoro.start(vim.g.nomodoro.long_break_time)
    end
end

function nomodoro.is_short_break()
    return vim.g.break_count % vim.g.nomodoro.break_cycle ~= 0 or vim.g.break_count == 0
end

function nomodoro.setup(options)
    local new_config = vim.tbl_deep_extend('force', DEFAULT_OPTIONS, options)
    vim.g.nomodoro = new_config
    menu.has_dependencies = new_config.menu_available
end

local previous_status = nil
function nomodoro.status()
    local status_string = ""

    if previous_status then
      if nomodoro.is_pause() then
        return previous_status
      else
        previous_status = nil
      end
    end

    if nomodoro.is_running() or nomodoro.is_pause() then
        if time_remaining_seconds(total_minutes, start_time) <= 0 then
            state = DONE
            if is_work_time(total_minutes) then
                status_string = vim.g.nomodoro.texts.on_work_complete
                if not already_notified_end then
                    vim.g.nomodoro.on_work_complete()
                    already_notified_end = true
                    nomodoro.show_menu(2 + (nomodoro.is_short_break() and 0 or 1))
                end
            else
                status_string = vim.g.nomodoro.texts.on_break_complete
                if not already_notified_end then
                    vim.g.nomodoro.on_break_complete()
                    already_notified_end = true
                    vim.g.break_count = vim.g.break_count + 1
                    nomodoro.show_menu()
                end

            end
        else
            status_string = vim.g.nomodoro.texts.status_icon .. time_remaining(total_minutes, start_time)
        end
    end

    if nomodoro.is_pause() then
      previous_status = status_string
    end

    return status_string
end

function nomodoro.stop()
    state = DONE
end

function nomodoro.show_menu(focus_line)
    menu.show(nomodoro, focus_line)
end

-- Expose commands

command("NomoWork", function ()
	nomodoro.start(vim.g.nomodoro.work_time)
end, {})

command("NomoPause", function ()
	nomodoro.pause()
end, {})

command("NomoBreak", function ()
    nomodoro.start_break()
end, {})

command("NomoStop", function ()
    nomodoro.stop()
end, {})

command("NomoStatus", function ()
    print(nomodoro.status())
end, {})

command("NomoTimer", function (opts)
    nomodoro.start(opts.args)
end, {nargs = 1})

if menu.has_dependencies then
    command("NomoMenu", function()
        nomodoro.show_menu()
    end, {})
end

return nomodoro
