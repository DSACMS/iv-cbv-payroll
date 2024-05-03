def account_connected_stub
  '{
    "event": "accounts.connected",
    "name": "Account Connected",
    "data": {
        "account": "018f3fb8-47b7-7a9f-b95a-530117e8522e",
        "user": "018f110a-39c1-3a5f-826f-a004eb7ed0b5",
        "resource": {
            "id": "018f3fb8-47b7-7a9f-b95a-530117e8522e",
            "user": "018f110a-39c1-3a5f-826f-a004eb7ed0b5",
            "employers": [],
            "item": "item_000012375",
            "source": "argyle_sandbox",
            "created_at": "2024-05-03T18:29:52.780604Z",
            "updated_at": "2024-05-03T18:30:09.761659Z",
            "connection": {
                "status": "connected",
                "error_code": null,
                "error_message": null,
                "updated_at": "2024-05-03T18:30:09.137853Z"
            },
            "direct_deposit_switch": {
                "status": "idle",
                "error_code": null,
                "error_message": null,
                "updated_at": "2024-05-03T18:29:53.219572Z"
            },
            "availability": {
                "gigs": null,
                "paystubs": null,
                "payroll_documents": null,
                "identities": null,
                "ratings": null,
                "vehicles": null,
                "deposit_destinations": null,
                "user_forms": null
            },
            "ongoing_refresh": {
                "status": "idle"
            }
        }
    }
  }'
end
