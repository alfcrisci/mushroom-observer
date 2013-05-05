class AddConfidence < ActiveRecord::Migration
  def self.up
    add_column(:votes, :confidence, :enum, :default => :high, :null => false, :limit => [:high, :medium, :low])
  end

  def self.down
    remove_column :votes, :confidence
  end
end
