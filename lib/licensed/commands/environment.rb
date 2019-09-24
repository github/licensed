# frozen_string_literal: true
module Licensed
  module Commands
    class Environment < Command
      class AppEnvironment
        include Licensed::Sources::ContentVersioning

        attr_reader :config
        def initialize(config)
          @config = config
        end

        def to_h
          out = config.to_h.merge(
            # override data for any calculated properties
            "cache_path" => config.cache_path.to_s,
            "source_path" => config.source_path.to_s,
            "sources" => config.sources.map { |s| s.class.type },
            "version_strategy" => self.version_strategy
          )

          # don't report sub-apps
          out.delete("apps")
          # root is provided as a key on the top-level object
          out.delete("root")

          out
        end
      end

      def run(**options)
        super do |report|
          report["root"] = config.root.to_s
          report["git_repo"] = Licensed::Git.git_repo?
        end
      end

      def create_reporter(options)
        case options[:format]
          when "json"
            Licensed::Reporters::JsonReporter.new
          else
            Licensed::Reporters::YamlReporter.new
          end
      end

      protected

      def run_app(app)
        reporter.report_app(app) do |report|
          report.merge! AppEnvironment.new(app).to_h
          true
        end
      end
    end
  end
end
