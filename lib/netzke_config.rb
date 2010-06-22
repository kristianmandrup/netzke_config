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

  class_option :extjs, :type => :string, :default => nil, :desc => 'location of ExtJS 3.x.x library', :optional => true

  class_option :overwrite_all, :type => :boolean, :default => false, :desc => 'force overwrite of all files, including existing modules and links', :optional => true
  class_option :overwrite_links, :type => :boolean, :default => true, :desc => 'force overwrite of symbolic links', :optional => true  

  NETKE_GITHUB = 'http://github.com/skozlov'

  def main
    exit(-1) if !valid_context?
    configure_modules
    configure_extjs if options[:extjs] 
  end   

  protected

  def valid_context?
    if netzke_app? && rails3_app?
      true
    else
      say "Must be run from a Netzke rails3 application root directory", :red      
      false
    end
  end
  
  def configure_modules  
    create_module_container_dir  
    inside "#{location}" do
      ["netzke-core", "netzke-basepack"].each do |module_name|
        get_module module_name
        config_netzke_plugin module_name
      end        
    end
  end

  def create_module_container_dir
    if File.directory?(location)
      FileUtils.rm_rf location if options[:overwrite_all] 
      return
    end
    empty_directory "#{location}"
  end


  def get_module module_name
    if File.directory? module_name
      update_module module_name
    else
      create_module module_name
    end
  end

  def update_module module_name
    inside module_name do
      run "git checkout rails3"
      run "git rebase origin/rails3" 
      run "git pull" 
    end
  end
    
  def create_module module_name
    # create dir for module by cloning
    run "git clone #{NETKE_GITHUB}/#{module_name}.git #{module_name}" 
    inside module_name do
      run "git checkout rails3"
    end
  end

  def config_netzke_plugin module_name
    inside 'vendor/plugins' do
      module_src = local_module_src(module_name) 
      run "rm -f #{module_name}" if options[:overwrite_links]
      run "ln -s #{module_src} #{module_name}"
    end
  end

  def configure_extjs
    extjs_dir = options[:extjs]
    if !File.directory? extjs_dir
      say "No directory for extjs found at #{extjs_dir}", :red 
      return
    else
      inside extjs_dir do                
        if !File.exist? 'ext-all.js'
          say "Directory  #{extjs_dir} does not appear to contain a valid ExtJS library. File 'ext-all.js' missing.", :red
          return
        end
      end
      inside 'public' do     
        run "rm -f extjs" if options[:overwrite_links]        
        run "ln -s #{extjs_dir} extjs"    
      end
    end
  end

  private

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
                  
