# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'

class FakeInstrumentation
  attr_reader :name, :version, :config

  def initialize(name, version)
    @name = name
    @version = version
    @install = false
    @config = nil
  end

  def instance
    self
  end

  def installed?
    @install == true
  end

  def install(config)
    @install = true
    @config = config
  end
end

describe OpenTelemetry::Instrumentation::Registry do
  before do
    @_logger = OpenTelemetry.logger
  end

  after do
    OpenTelemetry.instance_variable_set(:@registry, nil)
    OpenTelemetry.logger = @_logger
  end

  let(:registry) do
    OpenTelemetry::Instrumentation::Registry.new
  end

  let(:instrumentation_1) do
    FakeInstrumentation.new('TestInstrumentation1', '0.1.1')
  end

  let(:instrumentation_2) do
    FakeInstrumentation.new('TestInstrumentation2', '0.3.2')
  end

  let(:instrumentations) do
    [instrumentation_1, instrumentation_2]
  end

  describe '#register, #lookup' do
    it 'registers and looks up instrumentations' do
      instrumentations.each { |i| registry.register(i) }

      instrumentations.each do |i|
        _(registry.lookup(i.name)).must_equal(i)
      end
    end
  end

  describe '#install_all' do
    before do
      instrumentations.each { |i| registry.register(i) }
    end

    describe 'when using defaults arguments' do
      it 'installs all registered instrumentations' do
        registry.install_all

        instrumentations.each do |i|
          _(i).must_be :installed?
          _(i.config).must_be_nil
        end
      end
    end

    describe 'when using instrumentation specific configs' do
      it 'installs all registered instrumentations' do
        registry.install_all(
          'TestInstrumentation1' => { a: 'a' },
          'TestInstrumentation2' => { b: 'b' }
        )

        _(instrumentation_1).must_be :installed?
        _(instrumentation_1.config).must_equal(a: 'a')

        _(instrumentation_2).must_be :installed?
        _(instrumentation_2.config).must_equal(b: 'b')
      end
    end
  end

  describe '#install' do
    before do
      instrumentations.each { |i| registry.register(i) }
    end

    describe 'when using defaults arguments' do
      it 'installs a specific instrumentation' do
        registry.install(%w[TestInstrumentation1])

        _(instrumentation_1).must_be :installed?
        _(instrumentation_1.config).must_be_nil

        _(instrumentation_2).wont_be :installed?
        _(instrumentation_2.config).must_be_nil
      end
    end

    describe 'when using instrumentation specific configs' do
      it 'installs a specific instrumentation' do
        registry.install(
          %w[TestInstrumentation1 TestInstrumentation2],
          'TestInstrumentation1' => { a: 'a' },
          'TestInstrumentation2' => { b: 'b' }
        )

        _(instrumentation_1).must_be :installed?
        _(instrumentation_1.config).must_equal(a: 'a')

        _(instrumentation_2).must_be :installed?
        _(instrumentation_2.config).must_equal(b: 'b')
      end
    end

    describe 'given an non-existent instrumentation' do
      before do
        @log_stream = StringIO.new
        OpenTelemetry.logger = ::Logger.new(@log_stream)
      end

      it 'reports a warning' do
        registry.install(%w[NotInstalled TestInstrumentation2],
                         'NotInstalled' => {},
                         'TestInstrumentation2' => { b: 'b' })

        _(@log_stream.string).must_match(/Could not install NotInstalled because it was not found/)

        _(instrumentation_2).must_be :installed?
        _(instrumentation_2.config).must_equal(b: 'b')
      end
    end
  end

  describe 'buggy instrumentations' do
    before do
      instrumentations.each { |i| registry.register(i) }
    end

    describe 'install' do
      it 'handles exceptions during installation' do
        expect(instrumentation_1).to receive(:install).and_raise('oops')

        registry.install(%w[TestInstrumentation1 TestInstrumentation2])

        _(instrumentation_2).must_be :installed?
      end
    end

    describe 'install_all' do
      it 'handles exceptions during installation' do
        expect(instrumentation_1).to receive(:install).and_raise('oops')

        registry.install_all

        _(instrumentation_2).must_be :installed?
      end
    end
  end
end
