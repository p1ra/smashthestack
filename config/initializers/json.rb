module ActiveSupport
  module JSON
    module Encoding
      remove_const :ESCAPED_CHARS
      ESCAPED_CHARS = {
        "\010" =>  '\b',
        "\f"   =>  '\f',
        "\n"   =>  '\n',
        "\r"   =>  '\r',
        "\t"   =>  '\t',
        '"'    =>  '\"',
        '\\'   =>  '\\\\',
        '>'    =>  '\u003E',
        '<'    =>  '\u003C',
        '&'    =>  '\u0026'
      }

      def self.escape(string)
        %("#{string.gsub(escape_regex) { |s| ESCAPED_CHARS[s] }}")
      end
    end
  end
end
