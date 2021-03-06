require 'abstract_unit'
require 'fixtures/person'
require 'active_support/core_ext/hash/conversions'

class ObservingTest < Test::Unit::TestCase
  cattr_accessor :history

  class PersonObserver < ActiveModel::Observer
    observe :person

    %w( after_create after_destroy after_save after_update
        before_create before_destroy before_save before_update).each do |method|
          define_method(method) { |*| log method }
    end

    private
      def log(method)
        (ObservingTest.history ||= []) << method.to_sym
      end
  end

  def setup
    @matz = { 'person' => { :id => 1, :name => 'Matz' } }.to_json

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/1.json", {}, @matz
      mock.post   "/people.json",   {}, @matz, 201, 'Location' => '/people/1.json'
      mock.put    "/people/1.json", {}, nil, 204
      mock.delete "/people/1.json", {}, nil, 200
    end

    PersonObserver.instance
  end

  def teardown
    self.history = nil
  end

  def test_create_fires_save_and_create_notifications
    rick = Person.create(:name => 'Rick')
    assert_equal [:before_save, :before_create, :after_create, :after_save], self.history
  end

  def test_update_fires_save_and_update_notifications
    person = Person.find(1)
    person.save
    assert_equal [:before_save, :before_update, :after_update, :after_save], self.history
  end

  def test_destroy_fires_destroy_notifications
    person = Person.find(1)
    person.destroy
    assert_equal [:before_destroy, :after_destroy], self.history
  end
end
