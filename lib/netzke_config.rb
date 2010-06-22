require 'active_support/inflector'
require 'thor'
require 'thor/group'

class NetzkeConfig < Thor::Group
  include Thor::Actions

  # group used when displaying thor tasks with: thor list or thor -T
  # group :netzke

  # Define arguments 
  argument :location, :type => :string, :default => '~/netzke/modules', :desc => 'location where netzke modules are stored' 
  # argument :my_arg_name, :type (:string, :hash, :array, :numeric), :default, :required, :optional, :desc, :banner

  class_option :extjs, :type => :string, :default => nil, :desc => 'location of ExtJS 3.x.x library'

  class_option :branch, :type => :string, :default => 'rails3', :desc => 'Branch to use for netzke modules'
  class_option :account, :type => :string, :default => 'skozlov', :desc => 'Github account to get Netzke plugins from'
  class_option :force_all, :type => :boolean, :default => false, :desc => 'Force force of all files, including existing modules and links'
  class_option :force_links, :type => :boolean, :default => true, :desc => 'Force force of symbolic links' 
  class_option :ext_version, :type => :string, :default => '3.2.1', :desc => 'ExtJS version to download'
  class_option :download, :type => :boolean, :default => false, :desc => 'Download ExtJS if not found in specified extjs location'

  # class_option :basepack, :type => :string, :desc => 'Github branch and account specification for basepack module, fx rails3@kmandrup'
  # class_option :core, :type => :string, :desc => 'Github branch and account specification for core module, fx master@skozlov'
  class_option :modules, :type => :string, :desc => 'module specifications for each module, fx neztke_ar:master@skozlov,netzke_core:rails3@kmandrup'

  GITHUB = 'http://github.com'

  def main  
    define_vars
    define_modules
    exit(-1) if !valid_context?
    configure_modules
    configure_extjs if options[:extjs] 
  end   

  protected
  attr_accessor :modules_config

  def define_vars       
    @modules_config ||= {}
    set_module_config 'netzke-basepack'
    set_module_config 'netzke-core' 
  end

  def define_modules
    @modules_config ||= {}
    return if !options[:modules]
    module_defs = options[:modules].split(",")
    
    module_defs.each do |module_spec|
      spec = module_spec.strip.split(":")
      module_name = spec[0] 
      branch, account = spec[1].split("@")            
      set_module_config module_name.to_sym, :branch => branch, :account => account
    end
  end

  def set_module_config name, module_options = {}
    puts "set_module_config: #{name}, #{module_options.inspect}"
    mconfig = modules_config[name.to_sym] = {}
#    if options[name]
      # configs = options[:"netzke-#{name}"].split('@')      
      # mconfig[:branch]  = module_options[:branch] || configs[0] || options[:branch]
      # mconfig[:account] = module_options[:branch] || configs[1] || options[:account]

      mconfig[:branch]  = module_options[:branch] || options[:branch]
      mconfig[:account] = module_options[:account] || options[:account]
#    end         
  end

  def module_config name 
    puts "module_config: #{name}, #{modules_config.inspect}"
    modules_config[name.to_sym]
  end
  
  def valid_context?
    if netzke_app? && rails3_app?
      true
    else
      say "Must be run from a Netzke rails3 application root directory", :red      
      false
    end
  end

  def get_module_names
    ["netzke-core", "netzke-basepack"] | modules_config.keys.map{|k| k.to_s}    
  end
  
  def configure_modules  
    create_module_container_dir  
    inside "#{location}" do
      get_module_names.each do |module_name|
        puts "handle module: #{module_name}"
        get_module module_name
        config_netzke_plugin module_name
      end        
    end
  end

  def create_module_container_dir
    if File.directory?(location)
      run "rm -rf #{location}" if force_all?
    end
    empty_directory "#{location}" if !File.directory?(location)
  end


  def get_module module_name   
    run "rm -rf #{module_name}" if force_all?
    if File.directory? module_name
      update_module module_name
    else
      create_module module_name
    end
  end

  def update_module module_name 
    config = module_config(module_name)          
    inside module_name do 
      branch = config[:branch]
      run "git checkout #{branch}"
      run "git rebase origin/#{branch}" 
      run "git pull" 
    end
  end
    
  def create_module module_name
    # create dir for module by cloning  
    config = module_config(module_name)    
    account = config[:account]    
    run "git clone #{netzke_github account}/#{module_name}.git #{module_name}" 
    inside module_name do   
      branch = config[:branch]      
      run "git checkout #{branch}"
    end
  end

  def config_netzke_plugin module_name
    inside 'vendor/plugins' do
      module_src = local_module_src(module_name) 
      run "rm -f #{module_name}" if force_links?
      run "ln -s #{module_src} #{module_name}"
    end
  end

  def configure_extjs
    extjs_dir = options[:extjs]
    if !File.directory? extjs_dir
      say "No directory for extjs found at #{extjs_dir}", :red        
      extjs_dir = download_extjs if download?
    end      
    
    return if !File.directory(extjs_dir)
    
    inside extjs_dir do                
      if !File.exist? 'ext-all.js'
        say "Directory  #{extjs_dir} does not appear to contain a valid ExtJS library. File 'ext-all.js' missing.", :red
        return
      end
    end
    inside 'public' do     
      run "rm -f extjs" if force_links?        
      run "ln -s #{extjs_dir} extjs"    
    end
  end

  private

  def download?
    options[:download]    
  end

  def force_all?
    options[:force_all]
  end    

  def force_links?
    options[:force_links]
  end    

  def branch
    options[:branch]
  end

  def download_extjs 
    extjs_dir = options[:extjs]
    run "mkdir -p #{extjs_dir}"
    run %Q{ cd #{extjs_dir} && curl -s -o extjs.zip "http://www.extjs.com/deploy/ext-#{ext_version}.zip" && unzip -q extjs.zip && rm extjs.zip }    
    File.join(extjs_dir, extjs)
  end

  def netzke_github account
    "#{GITHUB}/#{account}"
  end  

  def netzke_app?
    File.directory? 'lib/netzke'
  end

  def rails3_app?
    File.exist? 'Gemfile'
  end

  def local_module_src module_name
    "#{options[:location]}/#{module_name}"
  end
  
end
                  
