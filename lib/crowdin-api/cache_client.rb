module Crowdin
    class CacheClient < API
        def clear_cache
            @project_info = @files = @project = nil
        end

        def project_info
            @project_info ||= super
        end

        def files
            @files ||= super
        end

        def project
            @project ||= super
        end
    end
end
