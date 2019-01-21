# frozen_string_literal: true
module Licensed
  module Command
    class Version
      def initialize
        @ui = Licensed::UI::Shell.new
      end

      def run
        @ui.info(Licensed::VERSION)
        true
      end
    end
  end
end
