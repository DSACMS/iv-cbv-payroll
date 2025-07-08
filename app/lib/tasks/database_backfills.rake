namespace :database_backfills do
	task backfill_ids: :environment do
		PayrollAccount.where.not(pinwheel_account_id: nil).find_in_batches(batch_size: 1000) do |batch|
	     PayrollAccount.where(id: batch).update_all("aggregator_account_id = pinwheel_account_id")
	   end
	end
end
