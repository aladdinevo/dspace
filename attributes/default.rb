default[:dspace] = {
  :version  => '1.8.2',
  :dir      => '/dspace',
  :baseUrl  => 'http://localhost:8080',
  :url      => 'http://localhost:8080/xmlui',
  :hostname => 'localhost',
  :name     => 'DSpace Local',
  :database => {
    :type        => 'postgres',
    :host        => 'localhost',
    :port        => '5432',
    :url         => 'jdbc:postgresql://localhost:5432/dspace',
    :driver      => 'org.postgresql.Driver',
    :name        => 'dspace',
    :user        => 'dspace',
    :password    => 'dspace',
    :encoding    => 'UNICODE',
    :collation   => 'en_US.utf8',
    :template    => 'template0',
  },
  :mail     => {
    :server      => 'smtp.dspace.local',
    :from        => { :address => 'no-reply@dspace.local' },
    :admin       => 'no-reply@dspace.local',
  },
  :feedback => {
    :recipient   => 'no-reply@dspace.local',
  },
  :metadata => { :language => 'en_US' }
}
