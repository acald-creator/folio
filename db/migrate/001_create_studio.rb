Sequel.migration do
  change do
    create_table :clients do
      primary_key :id
      String :name, null: false
      String :slug, null: false, unique: true
      String :note, text: true
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end

    create_table :commissions do
      primary_key :id
      foreign_key :client_id, :clients, null: false, on_delete: :restrict
      String :title, null: false
      String :state, null: false, default: "inquiry"
      Date :due_on
      String :notes, text: true, null: false, default: ""
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      index :state
      index :due_on
    end

    create_table :assets do
      primary_key :id
      foreign_key :commission_id, :commissions, null: false, on_delete: :cascade
      String :label, null: false
      String :url, null: false
      DateTime :created_at, null: false
    end
  end
end
