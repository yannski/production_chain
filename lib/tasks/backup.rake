namespace :s3 do

  desc "Backup code, database, and scm to S3"
  task :backup => ["s3:backup:db", "s3:backup:shared"]

  namespace :backup do
    desc "Backup the database to S3"
    task :db do
      db_tmp_path = "#{Rails.root}/db/dump.tar.gz"
      Rake::Task['db:backup'].invoke
      send_to_s3(db_tmp_path)
    end
    
    desc "Backup the shared folder to S3"
    task :shared do
      cmd = " cd .. && tar czfh current/tmp/shared.tar.gz shared/"
      system(cmd) 

      shared_tmp_path = "#{Rails.root}/tmp/shared.tar.gz"
      send_to_s3(shared_tmp_path)
    end
  end
end

private

  def conn
    @s3_config ||= YAML.load_file("#{Rails.root}/config/amazon_s3.yml")[Rails.env]
    @conn ||= Aws::S3.new(@s3_config['access_key_id'], @s3_config['secret_access_key'])
  end

  def bucket_name
    "#{Rails.root.to_s.split('/').last}-backup"
  end

  def backup_bucket
    create = conn.buckets.collect{ |b| b.name }.include?(bucket_name) ? false : true
    conn.bucket(bucket_name, create, 'private', :location => :eu)  
  end

  def send_to_s3 local_file_path
    bucket = backup_bucket
    s3_file_path = Time.now.strftime("%Y%m%d") + '/' + local_file_path.split('/').last
    bucket.put(s3_file_path, File.open(local_file_path))
  end