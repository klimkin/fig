# coding: utf-8

require 'set'

module Fig; end

# A statement within a package definition file (package.fig).
class Fig::Statement
  ENVIRONMENT_VARIABLE_NAME_REGEX = %r< \A \w+ \z >x

  attr_reader :line, :column, :source_description

  def self.position_description(line, column, source_description)
    if not line or not column
      return '' if not source_description

      return " (#{source_description})"
    end

    description = " (line #{line}, column #{column}"
    if source_description
      description << ", #{source_description}"
    end
    description << ')'

    return description
  end

  # Parameter will be modified.
  #
  # Takes a block that is invoked when there is an error.  Block receives a
  # single parameter of an error message that is the end of a statement
  # describing the problem, with no leading space character.  For example,
  # given «'foo», the block will receive a message like 'has unbalanced single
  # quotes.'.
  #
  # Returns whether parameter was single-quoted; if there was a parse error,
  # then the return value will be nil (and the block will have been invoked).
  def self.strip_quotes_and_process_escapes!(
    string, subexpression_matchers = DEFAULT_SUBEXPRESSION_MATCHER, &error_block
  )
    return false if string.length == 0

    replaced_quotes =
      strip_single_quotes_and_process_escapes!(string, &error_block)
    return true if replaced_quotes
    return      if replaced_quotes.nil?

    return strip_double_quotes_and_process_escapes!(
      string, subexpression_matchers, &error_block
    )
  end

  private

  DEFAULT_SUBEXPRESSION_MATCHER = [
    { :pattern => %r<\@>, :action => lambda {|character| character} }
  ]

  def self.strip_single_quotes_and_process_escapes!(string, &error_block)
    return false if string[0..0] != %q<'> && string[-1..-1] != %q<'>
    return false if string =~ %r< \A (?: \\{2} )* \\ ' \z >x # «\'» is legal

    if (
      string.length  == 1                         ||
      string[0..0]   != %q<'>                     ||
      string[-1..-1] != %q<'>                     ||
      string =~ %r< [^\\] (?: \\{2} )* \\ ' \z >x
    )
      yield 'has unbalanced single quotes.'
      return
    end

    if string =~ %r< [^\\] (?: \\{2} )*? \\ ([^\\']) >x
      yield "contains a bad escape sequence (\\#{$1}) inside single quotes."
      return
    end

    string.sub!( %r< \A ' (.*) ' \z >xm, '\1')
    string.gsub!(%r< \\ (.) >xm,         '\1')

    return true
  end

  def self.strip_double_quotes_and_process_escapes!(
    string, subexpression_matchers, &error_block
  )
    return if ! check_and_strip_double_quotes(string, &error_block)

    if string == %q<\\'>
      string.replace %q<'>
      return false
    end

    return if ! tokenize(string, subexpression_matchers, &error_block)

    # Needs to go away once we're using TokenizedString.
    string.gsub!(%r< \\ (.) >xm, '\1')

    return false
  end

  def self.check_and_strip_double_quotes(string, &error_block)
    # We accept any unquoted single character at this point.  Later validation
    # will catch bad characters.
    return true if string =~ %r< \A \\ . \z >xm

    if string[0..0] == %q<">
      if string.length == 1 || string[-1..-1] != %q<">
        yield 'has unbalanced double quotes.'
        return
      end
      if string =~ %r< [^\\] (?: \\{2} )*? \\ " \z >xm
        yield 'has unbalanced double quotes; the trailing double quote is escaped.'
        return
      end

      string.sub!( %r< \A " (.*) " \z >xm, '\1' )
    elsif string =~ %r< (?: \A | [^\\] ) (?: \\{2} )* " \z >xm
      yield %q<has unbalanced double quotes; it ends in a double quote when it didn't start with one.>
      return
    end

    return true
  end

  def self.tokenize(string, subexpression_matchers, &error_block)
    new_string     = ''
    working_string = string.clone

    while ! working_string.empty?
      if working_string =~ %r< \A (\\+) ([^\\] .*)? \z >xm
        slashes, remainder = $1, $2
        if slashes.length % 2 == 1
          if remainder.nil?
            yield 'ends in an incomplete escape.'
            return
          end
          if (
                subexpression_match(remainder, subexpression_matchers) \
            ||  remainder[0..0] == %q<">
          )
            new_string << slashes
            new_string << remainder[0..0]
            working_string = remainder[1..-1] || ''
          else
            yield "contains a bad escape sequence (\\#{$1})."
            return
          end
        else
          new_string << slashes
          working_string = remainder
        end
      else
        replacement, remainder =
          subexpression_match(working_string, subexpression_matchers)
        if replacement
          new_string << replacement
          working_string = remainder
        elsif working_string =~ %r< \A (["']) >xm
          quote_name = $1 == %q<'> ? 'single' : 'double'
          yield "contains an unescaped #{quote_name} quote."
          return
        else
          new_string << working_string[0..0]
          working_string = working_string[1..-1] || ''
        end
      end
    end

    return true
  end

  def self.subexpression_match(string, subexpression_matchers)
    subexpression_matchers.each do
      |matcher|

      pattern = matcher[:pattern]
      if string =~ %r< \A ( #{pattern} ) >x
        subexpression, remainder = $1, $'
        replacement = matcher[:action].call subexpression
        return [replacement, remainder]
      end
    end

    return
  end

  public

  # This mess of getting these as a single array necessary is due to
  # limitations of the "*" array splat operator in ruby v1.8.
  def initialize(line_column, source_description)
    if line_column
      @line, @column = *line_column
    end

    @source_description = source_description
  end

  # A name for this kind of Statement, usually a keyword for this statement as
  # it appears in package definition files.
  def statement_type()
    raise NotImplementedError
  end

  # Block will receive a Statement.
  def walk_statements(&block)
    return
  end

  def unparse_as_version(unparser)
    raise NotImplementedError
  end

  # Returns a two element array containing the version and an explanation of
  # why the version is necessary if the version is greater than 0.
  def minimum_grammar_for_emitting_input()
    raise NotImplementedError
  end

  # Returns a two element array containing the version and an explanation of
  # why the version is necessary if the version is greater than 0.
  def minimum_grammar_for_publishing()
    raise NotImplementedError
  end

  def urls()
    return []
  end

  def is_asset?()
    return false
  end

  def is_environment_variable?()
    return false
  end

  # Returns a representation of the position of this statement, if the position
  # is known, empty string otherwise.  This is written with the idea that you
  # can do something like "puts %Q<Found a
  # statement%{statement.position_string()}.>" and get nice looking output
  # regardless of whether the position is actually known or not.
  def position_string
    return Fig::Statement.position_description(
      @line, @column, @source_description
    )
  end
end

# vim: set fileencoding=utf8 :
