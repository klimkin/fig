require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/environment'
require 'fig/package'
require 'fig/package/configuration'
require 'fig/package/set'

def new_example_environment(variable_value = 'whatever', retrieve_vars = {})
  retriever_double = double('retriever')
  retriever_double.stub(:with_package_config)
  environment = Fig::Environment.new(nil, nil, {'FOO' => 'bar'}, retriever_double)

  if retrieve_vars
    retrieve_vars.each do |name, path|
      environment.add_retrieve( name, path )
    end
  end

  %w< one two three >.each do
    |package_name|
    package =
      Fig::Package.new(
        package_name,
        "#{package_name}-version",
        "#{package_name}-directory",
        [Fig::Package::Configuration.new('default', [])]
      )
    environment.register_package(package)

    set_statement = Fig::Package::Set.new(
      "WHATEVER_#{package_name.upcase}", variable_value
    )
    environment.apply_config_statement(package, set_statement, nil)
  end

  return environment
end

def substitute_command(command)
  environment = new_example_environment

  substituted_command = nil
  environment.execute_shell(command) {
    |command_line|
    substituted_command = command_line
  }

  return substituted_command
end

def substitute_variable(variable_value)
  environment = new_example_environment(variable_value)

  output = nil
  environment.execute_shell([]) {
    output = %x[
      echo $WHATEVER_ONE; echo $WHATEVER_TWO; echo $WHATEVER_THREE;
    ]
  }

  return output
end

describe 'Environment' do
  it 'can hand back a variable' do
    environment = new_example_environment

    environment['FOO'].should == 'bar'
  end

  describe 'package name substitution in commands' do
    it 'can replace bare names' do
      substituted_command = substitute_command %w< @one >

      substituted_command.should == %w< one-directory >
    end

    it 'can replace prefixed names' do
      substituted_command = substitute_command %w< something@one >

      substituted_command.should == %w< somethingone-directory >
    end

    it 'can replace multiple names in a single argument' do
      substituted_command = substitute_command %w< @one@two@three >

      substituted_command.should == %w< one-directorytwo-directorythree-directory >
    end

    it 'can replace names in multiple arguments' do
      substituted_command = substitute_command %w< @one @two >

      substituted_command.should == %w< one-directory two-directory >
    end

    it 'can handle simple escaped names' do
      substituted_command = substitute_command %w< \@one\@two >

      substituted_command.should == %w< @one@two >
    end

    it 'can handle escaped backslash' do
      substituted_command = substitute_command %w< bar\\\\foo >

      substituted_command.should == %w< bar\\foo >
    end

    it 'can handle escaped backslash in front of @' do
      substituted_command = substitute_command %w< bar\\\\@one >

      substituted_command.should == %w< bar\\one-directory >
    end

    it 'can handle escaped backslash in front of escaped @' do
      substituted_command = substitute_command %w< bar\\\\\\@one >

      substituted_command.should == %w< bar\\@one >
    end

    it 'complains about unknown escapes' do
      expect {
        # Grrr, Ruby syntax: that's three backslashes followed by "f"
        substitute_command %w< bar\\\\\\foo >
      }.to raise_error(/unknown escape/i)
    end
  end

  describe 'package name substitution in variables' do
    it 'does basic @ substitution' do
      output = substitute_variable('@/foobie')

      output.should ==
        "one-directory/foobie\ntwo-directory/foobie\nthree-directory/foobie\n"
    end

    it 'does @ escaping' do
      output = substitute_variable('\\@/foobie')

      output.should == "@/foobie\n@/foobie\n@/foobie\n"
    end

    it 'does retrieve variables [package] substitution' do
      retrieve_vars = {'WHATEVER_ONE' => 'foo.[package].bar'}
      environment = new_example_environment('blah', retrieve_vars)

      output = nil
      environment.execute_shell([]) {
        output = %x[
          echo $WHATEVER_ONE; echo $WHATEVER_TWO; echo $WHATEVER_THREE;
        ]
      }

      output.should == "foo.one.bar/blah\nblah\nblah\n"
    end
  end
end
