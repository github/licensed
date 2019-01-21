# frozen_string_literal: true

class TestShell < Licensed::UI::Shell
  attr_reader :messages

  def initialize
    super
    @messages = []
  end

  def debug(msg, newline = true)
    return unless level?("debug")
    @messages << {
      message: msg,
      newline: newline,
      style: :debug
    }
  end

  def info(msg, newline = true)
    return unless level?("info")
    @messages << {
      message: msg,
      newline: newline,
      style: :info
    }
  end

  def confirm(msg, newline = true)
    return unless level?("confirm")
    @messages << {
      message: msg,
      newline: newline,
      style: :confirm
    }
  end

  def warn(msg, newline = true)
    return unless level?("warn")
    @messages << {
      message: msg,
      newline: newline,
      style: :warn
    }
  end

  def error(msg, newline = true)
    return unless level?("error")
    @messages << {
      message: msg,
      newline: newline,
      style: :error
    }
  end
end
