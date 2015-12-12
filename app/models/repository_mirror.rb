class RepositoryMirror < ActiveRecord::Base
  unloadable

  PUSHMODE_MIRROR       = 0
  PUSHMODE_FORCE        = 1
  PUSHMODE_FAST_FORWARD = 2
  
  GIT_SSH_URL_REGEX = /\A(ssh:\/\/)([\w\-\.@]+)(\:[\d]+)?([\w\/\-\.~]+)(\.git)?\z/i
  GIT_REFSPEC_REGEX = /\A\+?([^:]*)(:([^:]*))?\z/
  
  ## Attributes
  attr_accessible :repository_id, :url, :push_mode, :include_all_branches, :include_all_tags, :explicit_refspec, :active

  ## Relations
  belongs_to :repository

  ## Validations
  validates :repository_id, presence: true
  validates_associated :repository

  ## Only allow SSH format
  ## ssh://git@redmine.example.org/project1/project2/project3/project4.git
  ## ssh://git@redmine.example.org:2222/project1/project2/project3/project4.git
#  validates_format_of :url, with: URI::regexp(%w(ssh)), allow_blank: false
  validates_format_of :url, with: GIT_SSH_URL_REGEX, allow_blank: false
  validates_uniqueness_of :url, scope: [:repository_id]
  validates :push_mode, presence: true
  validates_inclusion_of :push_mode, in: [PUSHMODE_MIRROR, PUSHMODE_FORCE, PUSHMODE_FAST_FORWARD]

  ## Additional validations
  validate :mirror_configuration

  ## Scopes
  scope :active,               -> { where(active: true) }
  scope :inactive,             -> { where(active: false) }
  scope :has_explicit_refspec, -> { where(push_mode: '> 0') }

  ## Callbacks
  before_validation :strip_whitespace


  def mirror_mode?
    push_mode == PUSHMODE_MIRROR
  end


  def force_mode?
    push_mode == PUSHMODE_FORCE
  end


  def push_mode_to_s
    case push_mode
    when 0
      'mirror'
    when 1
      'force'
    when 2
      'fast_forward'
    end
  end


  private


  # Strip leading and trailing whitespace
  def strip_whitespace
    self.url = url.strip rescue ''
    self.explicit_refspec = explicit_refspec.strip rescue ''
  end


  def mirror_configuration
    if mirror_mode?
      reset_fields
    elsif include_all_branches? && include_all_tags?
      mutual_exclusion_error
    elsif !explicit_refspec.blank?
      if include_all_branches?
        errors.add(:explicit_refspec, "cannot be used with Push all branches.")
      else
        validate_refspec
      end
    elsif !include_all_branches? && !include_all_tags?
      errors.add(:base, "Must include at least one item to push.")
    end
  end


  # Check format of refspec
  #
  def validate_refspec
    begin
      valid_git_refspec_path?(explicit_refspec)
    rescue => e
      errors.add(:explicit_refspec, e.message)
    end
  end


  def reset_fields
    # clear out all extra parameters.. (we use javascript to hide them anyway)
    self.include_all_branches = false
    self.include_all_tags     = false
    self.explicit_refspec     = ''
  end


  def mutual_exclusion_error
    errors.add(:base, "Cannot Push all branches and Push all tags at the same time.")
    unless explicit_refspec.blank?
      errors.add(:explicit_refspec, "cannot be used with Push all branches or Push all tags")
    end
  end

    
    
    
      
  # Validate a Git SSH urls
  # ssh://git@redmine.example.org/project1/project2/project3/project4.git
  # ssh://git@redmine.example.org:2222/project1/project2/project3/project4.git
  #
  #GIT_SSH_URL_REGEX = /\A(ssh:\/\/)([\w\-\.@]+)(\:[\d]+)?([\w\/\-\.~]+)(\.git)?\z/i
  
  def valid_git_ssh_url?(url)
    url.match(GIT_SSH_URL_REGEX)
  end
  
  
  # Validate a Git refspec
  # [+]<src>:<dest>
  # [+]refs/<name>/<ref>:refs/<name>/<ref>
  #
  #GIT_REFSPEC_REGEX = /\A\+?([^:]*)(:([^:]*))?\z/
  
  def valid_git_refspec?(refspec)
    refspec.match(GIT_REFSPEC_REGEX)
  end
  
  
  def valid_git_refspec_path?(refspec)
    refspec_parsed = valid_git_refspec?(refspec)
    if refspec_parsed.nil? || !valid_refspec_path?(refspec_parsed[1]) || !valid_refspec_path?(refspec_parsed[3])
      raise "Bad format"
    elsif !refspec_parsed[1] || refspec_parsed[1] == ''
      raise "Null component"
    end
  end
  
  
  # Allow null or empty components
  #
  def valid_refspec_path?(refspec)
    !refspec || refspec == '' || parse_refspec(refspec) ? true : false
  end


    






  REF_COMPONENT_PART  = '[\\.\\-\\w_\\*]+'
  REF_COMPONENT_REGEX = /\A(refs\/)?((#{REF_COMPONENT_PART})\/)?(#{REF_COMPONENT_PART}(\/#{REF_COMPONENT_PART})*)\z/
  
  # Parse a reference component. Two possibilities:
  #
  # 1) refs/type/name
  # 2) name
  #
  def parse_refspec(spec)
    parsed_refspec = spec.match(REF_COMPONENT_REGEX)
    return nil if parsed_refspec.nil?
    if parsed_refspec[1]
      # Should be first class.  If no type component, return fail
      if parsed_refspec[3]
        { type: parsed_refspec[3], name: parsed_refspec[4] }
      else
        nil
      end
    elsif parsed_refspec[3]
      { type: nil, name: "#{parsed_refspec[3]}/#{parsed_refspec[4]}" }
    else
      { type: nil, name: parsed_refspec[4] }
    end
  end
  
  
  def author_name(committer)
    committer.gsub(/\A([^<]+)\s+.*\z/, '\1')
  end
  
  
  def author_email(committer)
    committer.gsub(/\A.*<([^>]+)>.*\z/, '\1')
  end

end
