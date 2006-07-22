require 'digest/sha1'

# this model expects a certain database layout and its based on the name/login pattern. 
class User < ActiveRecord::Base
  
  has_many :comments
  has_many :images
  has_many :observations
  has_many :species_lists

  def self.authenticate(login, pass)
    find_first(["login = ? AND password = ?", login, sha1(pass)])
  end  

  def change_password(pass)
    update_attribute "password", self.class.sha1(pass)
  end

  def change_email(email)
    self.email = email
  end

  def change_name(name)
    self.name = name
  end

  def change_theme(theme)
    self.theme = theme
  end
  
  def unique_name()
    if self.name
      sprintf("%s (%s)", self.name, self.login)
    else
      self.login
    end
  end
  
  def legal_name()
    if self.name
      self.name
    else
      self.login
    end
  end
  
  protected

  def self.sha1(pass)
    # Digest::SHA1.hexdigest("change-me--#{pass}--")
    Digest::SHA1.hexdigest("something__#{pass}__")
  end
    
  before_create :crypt_password
  
  def crypt_password
    write_attribute("password", self.class.sha1(password))
  end

  validates_length_of :login, :within => 3..40
  validates_length_of :password, :within => 5..40
  validates_presence_of :login, :password, :email
  validates_presence_of :password_confirmation, :on => :create
  validates_uniqueness_of :login, :on => :create
  validates_confirmation_of :password, :on => :create     
end