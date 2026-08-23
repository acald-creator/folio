Sequel.migration do
  up do
    alter_table :commissions do
      add_column :listing, String, text: true, null: false, default: ""
    end

    from(:commissions).where(state: "inquiry").update(state: "saved")
    from(:commissions).where(state: "booked").update(state: "applied")
    from(:commissions).where(state: "making").update(state: "interview")
    from(:commissions).where(state: "review").update(state: "offer")
    from(:commissions).where(state: "done").update(state: "closed")

    create_table :profiles do
      primary_key :id
      String :name, null: false, default: ""
      String :headline, null: false, default: ""
      String :summary, text: true, null: false, default: ""
      String :skills, text: true, null: false, default: "[]"
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end

  down do
    drop_table :profiles
    alter_table :commissions do
      drop_column :listing
    end
  end
end
