class User 
  include Tire::Model::Persistence
  devise :database_authenticatable, :registerable, :recoverable, :rememberable
  associates :post, :topic

  property :remember_created_at,    type: 'date'
  property :reset_password_sent_at, type: 'date'
  property :reset_password_token,   type: 'string', index: 'not_analyzed'
  property :encrypted_password,     type: 'string', index: 'not_analyzed'
  property :username,                   type: 'string', index: 'not_analyzed'
  property :email,                  type: 'string', index: 'not_analyzed'
  property :created_at,             type: 'date',   default: Proc.new{ Time.now }
  property :role,                   type: 'string', index: 'not_analyzed', default: 'user'
  validates_presence_of :username, :email
  validates_confirmation_of :password

  def self.find_by_email(email)
    search(size: 1){ |s| s.query{ |q| q.term :email, email } }.first
  end

  LIST = {'noob' => 1, 'skiddie' => 2, 'coder' => 3, 'hacker' => 4, 'mentor' => 5, 'leet' => 6}
    .each{ |role, weight| define_method("#{role}?"){ self.role == role }}

  def self.available_roles
    LIST.sort_by(&:last).map {|role, weight| [role, role]}
  end

  def allowed?(role)
    LIST[self.role] >= LIST[role]
  end
end
