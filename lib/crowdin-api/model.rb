module Crowdin
    class API
        # Yes, the Crowdin API uses Eastern time for all timestamps,
        # but does not include the zone in the timestamp itself,
        # or mention anything about this in documentation.
        #
        # I'm not even certain this is what they are doing,
        # but it's my best guess based on experimentation.
        # I have no clue what will happen around DST transitions.
        #
        # Pretty impressive from a company specializing in i18n!

        TIME_ZONE = TZInfo::Timezone.get('America/New_York')
        TIME_RE = /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/

        def files
            parse_files('', project_info['files'])
        end

        def project
            Project.new(project_info['details'])
        end

        private

        def parse_files(prefix, nodes)
            files = {}
            nodes.each do |node|
                path = "#{prefix}/#{node['name']}"
                case node['node_type']
                    when 'file'
                        files[path] = File.new(node, path)
                    when 'directory'
                        kids = parse_files(path, node['files'])
                        files[path] = Directory.new(node, path, kids)
                        files.merge!(kids)
                end
            end
            files
        end
    end

    class Model
        attr_reader :data

        def initialize(data)
            @data = data
        end

        class << self
            def raw_field(name)
                define_method name do
                    data[name.to_s]
                end
            end

            def integer_field(name)
                define_method name do
                    if x = data[name.to_s]
                        x.to_i
                    end
                end
            end

            def time_field(name)
                define_method name do
                    if x = data[name.to_s]
                        # Be super strict about parsing, so that if they ever do fix timestamps,
                        # this code will (hopefully) start failing loudly instead of silently
                        # parsing the wrong time.
                        if x =~ API::TIME_RE
                            # sec, min, hour, day, month, year, wday, yday, isdst, tz
                            Time.local($6, $5, $4, $3, $2, $1, nil, nil, nil, API::TIME_ZONE).utc
                        else
                            raise "Failed to parse timestamp, format may have changed (see code for important info)"
                        end
                    end
                end
            end
        end
    end

    class Project < Model
        raw_field :identifier
        raw_field :name
        raw_field :description
        raw_field :source_language
        raw_field :invite_url
        time_field :created
        time_field :last_build
        time_field :last_activity
        integer_field :participants_count
        integer_field :total_strings_count
        integer_field :total_words_count
        integer_field :duplicate_strings_count
        integer_field :duplicate_words_count
    end

    class Node < Model
        attr_reader :path
        raw_field :name

        def initialize(data, path)
            super(data)
            @path = path
        end
    end

    class Directory < Node
        attr_reader :files

        def initialize(data, path, files)
            super(data, path)
            @files = files
        end
    end

    class File < Node
        integer_field :last_revision
        time_field :created
        time_field :last_updated
        time_field :last_accessed
    end
end
