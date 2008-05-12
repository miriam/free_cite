class CreateCitations < ActiveRecord::Migration
  def self.up
    create_table :citations do |t|
      t.column :raw_string,  :text
      t.column :authors,     :text,     :default => "--- []"
    	t.column :title,       :text
    	t.column :year,        :integer
    	t.column :publisher,   :text
    	t.column :location,    :text
    	t.column :booktitle,   :text
    	t.column :journal,     :text
    	t.column :pages,       :text
    	t.column :volume,      :text
    	t.column :number,      :text
    	t.column :contexts,    :text,     :default => "--- []"
    	t.column :tech,        :text
    	t.column :institution, :text
    	t.column :editor,      :text
    	t.column :note,        :text
      t.column :marker_type, :string
      t.column :marker,      :string 
    end
  end

  def self.down
    drop_table :citations
  end
end
