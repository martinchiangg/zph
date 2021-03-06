#!/usr/bin/env crystal

# Load no gems beyond stdlib due to native extensions breaking
# and rebuilding between different ruby versions and chruby/system.
# Also should speed up script timing. ZPH
#########################################################
##  Generated Code: do not submit patches.
##  Submit patches against non-generated version of code.
#########################################################

#
# Colorize String class extension.
#
class String

  #
  # Colors Hash
  #
  COLORS = {
    :black          => 0,
    :red            => 1,
    :green          => 2,
    :yellow         => 3,
    :blue           => 4,
    :magenta        => 5,
    :cyan           => 6,
    :white          => 7,
    :default        => 9,

    :light_black    => 60,
    :light_red      => 61,
    :light_green    => 62,
    :light_yellow   => 63,
    :light_blue     => 64,
    :light_magenta  => 65,
    :light_cyan     => 66,
    :light_white    => 67
  }

  #
  # Modes Hash
  #
  MODES = {
    :default        => 0, # Turn off all attributes
    :bold           => 1, # Set bold mode
    :underline      => 4, # Set underline mode
    :blink          => 5, # Set blink mode
    :swap           => 7, # Exchange foreground and background colors
    :hide           => 8  # Hide text (foreground color would be the same as background)
  }

  REGEXP_PATTERN = /\033\[([0-9]+);([0-9]+);([0-9]+)m(.+?)\033\[0m|([^\033]+)/m
  COLOR_OFFSET = 30
  BACKGROUND_OFFSET = 40

  #
  # Change color of string
  #
  # Examples:
  #
  #   puts "This is blue".colorize(:blue)
  #   puts "This is light blue".colorize(:light_blue)
  #   puts "This is also blue".colorize(:color => :blue)
  #   puts "This is light blue with red background".colorize(:color => :light_blue, :background => :red)
  #   puts "This is light blue with red background".colorize(:light_blue ).colorize( :background => :red)
  #   puts "This is blue text on red".blue.on_red
  #   puts "This is red on blue".colorize(:red).on_blue
  #   puts "This is red on blue and underline".colorize(:red).on_blue.underline
  #   puts "This is blue text on red".blue.on_red.blink
  #   puts "This is uncolorized".blue.on_red.uncolorize
  #
  def colorize(params)
    self.scan(REGEXP_PATTERN).inject("") do |str, match|
      match[0] ||= MODES[:default]
      match[1] ||= COLORS[:default] + COLOR_OFFSET
      match[2] ||= COLORS[:default] + BACKGROUND_OFFSET
      match[3] ||= match[4]

      if (params.instance_of?(Hash))
        match[0] = MODES[params[:mode]] if params[:mode] && MODES[params[:mode]]
        match[1] = COLORS[params[:color]] + COLOR_OFFSET if params[:color] && COLORS[params[:color]]
        match[2] = COLORS[params[:background]] + BACKGROUND_OFFSET if params[:background] && COLORS[params[:background]]
      elsif (params.instance_of?(Symbol))
        match[1] = COLORS[params] + COLOR_OFFSET if params && COLORS[params]
      end

      str << "\033[#{match[0]};#{match[1]};#{match[2]}m#{match[3]}\033[0m"
    end
  end

  #
  # Return uncolorized string
  #
  def uncolorize
    self.scan(REGEXP_PATTERN).inject("") do |str, match|
      str << (match[3] || match[4])
    end
  end

  #
  # Return true if string is colorized
  #
  def colorized?
    self.scan(REGEXP_PATTERN).reject do |match|
      match.last
    end.any?
  end

  macro define_method(name, content)
    def {{name}}
      self.{{content}}
    end
  end
  #
  # Make some color and on_color methods
  #
  #COLORS.each_key do |key|
  #  next if key == :default

  #  define_method key, colorize(color: key)
  #  define_method "on_#{key}", colorize(background: key)
  #end

  ##
  ## Methods for modes
  ##
  #MODES.each_key do |key|
  #  next if key == :default

  #  define_method key, colorize(mode: key)
  #end

  #
  # Return array of available modes used by colorize method
  #
  def self.modes
    MODES.keys
  end

  #
  # Return array of available colors used by colorize method
  #
  def self.colors
    COLORS.keys
  end

  #
  # Display color matrix with color names
  #
  def self.color_matrix(txt = "[X]")
    size = String.colors.length
    String.colors.each do |color|
      String.colors.each do |back|
        print txt.colorize(color: color, background: back)
      end
      puts " < #{color}"
    end
    String.colors.reverse.each_with_index do |back, index|
      puts "#{"|".rjust(txt.length)*(size-index)} < #{back}"
    end
    ""
  end
end

class GitSmart
end

module SafeShell
  def self.execute(command, *args)
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    process = Process.new(command, *args, output: stdout, error: stderr)
    status = process.wait
    [stdout, stderr].join("").to_s
  end

  def self.execute?(*args)
    execute(*args)
    $?.success?
  end
end
class GitSmart
  def self.run(code, args)
    lambda = commands[code]
    if lambda
      begin
        lambda.call(args)
      rescue e : GitSmart::Exception
        if e.message && !e.message.empty?
          puts e.message.colorize(color: :red)
        end
      end
    else
      puts "No command #{code.inspect} defined! Available commands are #{commands.keys.sort.inspect}"
    end
  end

  # Used like this:
  # GitSmart.register 'my-command' do |repo, args|
  def self.register(code, &blk : GitRepo, Array(String) ->)
    commands[code] = ->(repo : GitRepo, args : Array(String)) {
      blk.call(GitRepo.new("."), repo, args)
    }
  end

  def self.commands
    @@commands ||= {} of String => Proc(String, Array(String))
  end
end

require "yaml"

class Pathname
  def initialize(@base : String)
  end

  def join(path : String)
    [@base, path].join("/")
  end
end

class GitRepo
  def initialize(dir : String)
    @dir = dir
    unless File.directory?(git_dir)
      raise GitSmart::RunFailed.new(
        <<-MSG.gsub(/^\s+/, "")
        You need to run this from within a Git directory.
        Current working directory: #{File.expand_path(dir)}
        Expected .git directory: #{git_dir}
        MSG
      )
    end
  end

  def git_dir
    gitdir = Pathname.new(@dir).join(".git")

    unless File.exists?(gitdir)
      @dir = git("rev-parse", "--show-toplevel").chomp
      gitdir = Pathname.new(@dir).join(".git") unless @dir.empty?
    end

    if File.file?(gitdir)
      submodule = YAML.parse(File.read(gitdir))
      gitdir = Pathname.new(@dir).join(submodule["gitdir"].to_s)
    end

    gitdir
  end

  def current_branch
    head_file = File.join(git_dir, "HEAD")
    File.read(head_file).strip.sub(%r(^.*refs/heads/), "")
  end

  def sha(ref)
    sha = git("rev-parse", ref).chomp
    sha.empty? ? nil : sha
  end

  def tracking_remote
    config("branch.#{current_branch}.remote")
  end

  def tracking_branch
    key   = "branch.#{current_branch}.merge"
    value = config(key)
    if value.nil?
      value
    elsif value =~ /^refs\/heads\/(.*)$/
      $1
    else
      raise GitSmart::UnexpectedOutput.new("Expected the config of '#{key}' to be /refs/heads/branchname, got '#{value}'")
    end
  end

  def fetch!(remote)
    git!("fetch", remote)
  end

  def merge_base(ref_a, ref_b)
    git("merge-base", ref_a, ref_b).chomp
  end

  def exists?(ref)
    git("rev-parse", ref)
    $?.success?
  end

  def rev_list(ref_a, ref_b)
    git("rev-list", "#{ref_a}..#{ref_b}").split("\n")
  end

  def raw_status
    git("status", "-s")
  end

  def status
    raw_status.
      split("\n").
      map { |l| l.split(" ") }.
      group_by(&:first).
      map_values { |lines| lines.map(&:last) }.
      map_keys { |status|
        case status
          when /^[^ ]*M/; :modified
          when /^[^ ]*A/; :added
          when /^[^ ]*D/; :deleted
          when /^[^ ]*\?\?/; :untracked
          when /^[^ ]*UU/; :conflicted
          else raise GitSmart::UnexpectedOutput.new("Expected the output of git status to only have lines starting with A, M, D, UU, or ??. Got: \n#{raw_status}")
        end
      }
  end

  def dirty?
    status.any? { |k,v| k != :untracked && v.any? }
  end

  def fast_forward!(upstream)
    git!("merge", "--ff-only", upstream)
  end

  def stash!
    git!("stash")
  end

  def stash_pop!
    git!("stash", "pop")
  end

  def rebase_preserving_merges!(upstream)
    git!("rebase", "-p", upstream)
  end

  def read_log(nr)
    git("log", "--oneline", "-n", nr.to_s).split("\n").map { |l| l.split(" ",2) }
  end

  def last_commit_messages(nr)
    read_log(nr).map(&:last)
  end

  def log_to_shell(*args)
    git_shell("log", *args)
  end

  def merge_no_ff!(target)
    git!("merge", "--no-ff", target)
  end

  # helper methods, left public in case other commands want to use them directly

  def git(*args)
    output = exec_git(*args).to_s
    $?.success? ? output : ""
  end

  def git!(*args)
    cmd = ["git", args].join(" ")
    puts "Executing: #{cmd}"
    output = exec_git(*args)
    to_display = output.split("\n").map { |l| "  #{l}" }.join("\n")
    $?.success? ? puts(to_display) : raise(GitSmart::UnexpectedOutput.new(to_display))
    output
  end

  def git_shell(*args)
    puts "Executing: git #{args}"
    Dir.cd(@dir) {
      system("git", args)
    }
  end

  def config(name)
    remote = git("config", name).chomp
    remote.empty? ? nil : remote
  end

  def exec_git(*args)
    return if @dir.empty?
    Dir.cd(@dir) {
      SafeShell.execute("git", args)
    }
  end
end
# The context that commands get executed within. Used for defining and scoping helper methods.

def start(msg)
  puts "- #{msg} -".colorize(color: :green)
end

def note(msg)
  puts "* #{msg}"
end

def warn(msg)
  puts msg.colorize(color: :red)
end

def puts_with_done(msg, &blk)
  print "#{msg}..."
  blk.call
  puts "done."
end

def success(msg)
  puts big_message(msg).green
end

def failure(msg)
  puts big_message(msg).red
  raise GitSmart::RunFailed
end

def big_message(msg)
  spacer_line = (" " + "-" * (msg.length + 20) + " ")
  [spacer_line, "|" + " " * 10 + msg + " " * 10 + "|", spacer_line].join("\n")
end

class GitSmart
  class Exception < ::Exception
    def initialize(msg = "")
      super(msg)
    end
  end

  class RunFailed < Exception; end
  class UnexpectedOutput < Exception; end
end
#This is a super simple alias for the most badass of log outputs that git
#offers. Uses git log --graph under the hood.
#
#Thanks to [@ben_h](http://twitter.com/ben_h) for this one!
GitSmart.register "smart-log" do |repo, args|
  #Super simple, passes the args through to git log, but
  #ratchets up the badassness quotient.
  repo.log_to_shell("--pretty=format:%C(yellow)%h%Cblue%d%Creset %s %C(white) %an, %ar%Creset", "--graph", *args)
end
#Calling `git smart-merge branchname` will, quite simply, perform a
#non-fast-forward merge wrapped in a stash push/pop, if that"s required.
#With some helpful extra output.
GitSmart.register "smart-merge" do |repo, args|
  #Let"s begin!
  current_branch = repo.current_branch
  start "Starting: smart-merge on branch '#{current_branch}'"

  #Grab the merge_target the user specified
  merge_target = args.shift
  failure "Usage: git smart-merge ref" if !merge_target

  #Make sure git can resolve the reference to the merge_target
  merge_sha = repo.sha(merge_target)
  failure "Branch to merge '#{merge_target}' not recognised by git!" if !merge_sha

  #If the SHA of HEAD and the merge_target are the same, we're trying to merge
  #the same commit with itself. Which is madness!
  head = repo.sha("HEAD")
  if merge_sha == head
    note "Branch '#{merge_target}' has no new commits. Nothing to merge in."
    success "Already up-to-date."
  else
    #Determine the merge-base of the two commits, so we can report some useful output
    #about how many new commits have been added.
    merge_base = repo.merge_base(head, merge_sha)

    #Report the number of commits on merge_target we're about to merge in.
    new_commits_on_merge_target = repo.rev_list(merge_base, merge_target)
    puts "Branch '#{merge_target}' has diverged by #{new_commits_on_merge_target.length} commit#{"s" if new_commits_on_merge_target.length != 1}. Merging in."

    #Determine if our branch has moved on.
    if head == merge_base
      #Note: Even though we _can_ fast-forward here, it's a really bad idea since
      #it results in the disappearance of the branch in history. For a good discussion
      #on this topic, see this [StackOverflow question](http://stackoverflow.com/questions/2850369/why-uses-git-fast-forward-merging-per-default).
      note "Branch '#{current_branch}' has not moved on since '#{merge_target}' diverged. Running with --no-ff anyway, since a fast-forward is unexpected behaviour."
    else
      #Report how many commits on our branch since merge_target diverged.
      new_commits_on_branch = repo.rev_list(merge_base, head)
      puts "Branch '#{current_branch}' has #{new_commits_on_branch.length} new commit#{"s" if new_commits_on_merge_target.length != 1} since '#{merge_target}' diverged."
    end

    #Before we merge, detect if there are local changes and stash them.
    stash_required = repo.dirty?
    if stash_required
      note "Working directory dirty. Stashing..."
      repo.stash!
    end

    #Perform the merge, using --no-ff.
    repo.merge_no_ff!(merge_target)

    #If we stashed before, pop now.
    if stash_required
      note "Reapplying local changes..."
      repo.stash_pop!
    end

    #Display a nice completion message in large, friendly letters.
    success "All good. Created merge commit #{repo.sha("HEAD")[0,7]}."
  end
end
#Calling `git smart-pull` will fetch remote tracked changes
#and reapply your work on top of it. It's like a much, much
#smarter version of `git pull --rebase`.
#
#For some background as to why this is needed, see [my blog
#post about the perils of rebasing merge commits](http://notes.envato.com/developers/rebasing-merge-commits-in-git/)
#
#This is how it works:

GitSmart.register "smart-pull" do |repo, args|
  #Let's begin!
  branch = repo.current_branch
  start "Starting: smart-pull on branch '#{branch}'"

  #Let's not have any arguments, fellas.
  warn "Ignoring arguments: #{args.inspect}" if !args.empty?

  #Try grabbing the tracking remote from the config. If it doesn't exist,
  #notify the user and default to 'origin'
  tracking_remote = repo.tracking_remote ||
    note("No tracking remote configured, assuming 'origin'") ||
    "origin"

  # Fetch the remote. This pulls down all new commits from the server, not just our branch,
  # but generally that's a good thing. This is the only communication we need to do with the server.
  repo.fetch!(tracking_remote)

  #Try grabbing the tracking branch from the config. If it doesn't exist,
  #notify the user and choose the branch of the same name
  tracking_branch = repo.tracking_branch ||
    note("No tracking branch configured, assuming '#{branch}'") ||
    branch

  #Check the specified upstream branch exists. Fail if it doesn't.
  upstream_branch = "#{tracking_remote}/#{tracking_branch}"
  failure("Upstream branch '#{upstream_branch}' doesn't exist!") if !repo.exists?(upstream_branch)

  #Grab the SHAs of the commits we'll be working with.
  head = repo.sha("HEAD")
  remote = repo.sha(upstream_branch)

  #If both HEAD and our upstream_branch resolve to the same SHA, there's nothing to do!
  if head == remote
    puts "Neither your local branch '#{branch}', nor the remote branch '#{upstream_branch}' have moved on."
    success "Already up-to-date"
  else
    #Find out where the two branches diverged using merge-base. It's what git
    #uses internally.
    merge_base = repo.merge_base(head, remote)

    #Report how many commits are new locally, since that's useful information.
    new_commits_locally = repo.rev_list(merge_base, head)
    if !new_commits_locally.empty?
      note "You have #{new_commits_locally.length} new commit#{"s" if new_commits_locally.length != 1} on '#{branch}'."
    end

    #By comparing the merge_base to both HEAD and the remote, we can
    #determine whether both or only one have moved on.
    #If the remote hasn't changed, we're already up to date, so there's nothing
    #to pull.
    if merge_base == remote
      puts "Remote branch '#{upstream_branch}' has not moved on."
      success "Already up-to-date"
    else
      #If the remote _has_ moved on, we actually have some work to do:
      #
      #First, report how many commits are new on remote. Because that's useful information, too.
      new_commits_on_remote = repo.rev_list(merge_base, remote)
      is_are, s_or_not = (new_commits_on_remote.length == 1) ? ["is", ""] : ["are", "s"]
      note "There #{is_are} #{new_commits_on_remote.length} new commit#{s_or_not} on '#{upstream_branch}'."

      #Next, detect if there are local changes and stash them.
      stash_required = repo.dirty?
      if stash_required
        note "Working directory dirty. Stashing..."
        repo.stash!
      end

      success_messages = [] of String

      #Then, bring the local branch up to date.
      #
      #If our local branch hasn't moved on, that's easy - we just need to fast-forward.
      if merge_base == head
        puts "Local branch '#{branch}' has not moved on. Fast-forwarding..."
        repo.fast_forward!(upstream_branch)
        success_messages << "Fast forwarded from #{head[0,7]} to #{remote[0,7]}"
      else
        #If our local branch has new commits, we need to rebase them on top of master.
        #
        #When we rebase, we use `git rebase -p`, which attempts to recreate merges
        #instead of ignoring them. For a description as to why, see my [blog post](http://notes.envato.com/developers/rebasing-merge-commits-in-git/).
        note "Both local and remote branches have moved on. Branch 'master' needs to be rebased onto 'origin/master'"
        repo.rebase_preserving_merges!(upstream_branch)
        success_messages << "HEAD moved from #{head[0,7]} to #{repo.sha("HEAD")[0,7]}."
      end

      #If we stashed before, pop now.
      if stash_required
        note "Reapplying local changes..."
        repo.stash_pop!
      end

      #Use smart-log to show the new commits.
      GitSmart.run("smart-log", ["#{merge_base}..#{upstream_branch}"])

      #Display a nice completion message in large, friendly letters.
      success ["All good.", success_messages].join(" ")
    end

    #Still to do:
    #
    #* Ensure ORIG_HEAD is correctly set at the end of each run.
    #* If the rebase fails, and you've done a stash, remind the user to unstash

  end
end
class Array
  def group_by(&blk)
    Hash.new { |h,k| h[k] = [] of Any }.tap do |hash|
      each do |element|
        hash[blk.call(element)] << element
      end
    end
  end
end
class Hash
  def map_keys(&blk)
    map_keys_with_values { |k,v| blk.call(k) }
  end

  def map_keys_with_values(&blk)
    result = {} of String => Any
    each { |k,v| result[blk.call(k,v)] = v}
    result
  end

  def map_values(&blk)
    map_values_with_keys { |k,v| blk.call(v) }
  end

  def map_values_with_keys(&blk)
    result = {} of String => Any
    each { |k,v| result[k] = blk.call(k,v)}
    result
  end
end
class Object
  def tapp(prefix = nil, &block)
    block ||= lambda {|x| x }
    str = if block[self].is_a?(String)
            block[self]
          else
            block[self].inspect
          end
    puts [prefix, str].compact.join(": ")
    self
  end
end

def main
  cmd = ARGV.shift
  case cmd
  when "pull", "merge", "log" then GitSmart.run("smart-#{cmd}", ARGV)
  else
    puts "Received unknown command #{cmd} when only pull, smart, and log are valid"
    exit(1)
  end
end

main
