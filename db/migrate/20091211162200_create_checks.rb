class CreateChecks < ActiveRecord::Migration
  def self.up
    create_table :checks do |t|
      t.string :object
      t.integer :object_id
      t.integer :status
      t.string :out_reason
      t.date :out_date
      t.integer :out_user
      t.string :in_reason
      t.date :in_date
      t.integer :in_user
      t.string :local_dir

      t.timestamps
    end
  end

  def self.down
    drop_table :checks
  end
end