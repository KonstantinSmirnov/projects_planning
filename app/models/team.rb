class Team < ApplicationRecord
  include Trackable

  DEFAULTS = [
    { name: "Launchpad", color: "#f97316" },
    { name: "NativeX", color: "#8b5cf6" },
    { name: "Commerce", color: "#10b981" }
  ].freeze

  has_many :tasks, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :color, presence: true, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #3b82f6" }

  def self.ordered
    order(:name)
  end

  def self.ensure_seeded!
    DEFAULTS.each { |attrs| create!(attrs) } if none?
  end

  def activity_label
    name
  end
end
