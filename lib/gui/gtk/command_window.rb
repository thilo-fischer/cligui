#!/usr/bin/env ruby

=begin
  cligui.rb - A GUI for calling arbitrary command line tools..

  Copyright (c) 2014 Thilo Fischer
  This program is licenced under GPLv3.
=end

require 'gtk2'
require_relative 'window.rb'

class CliDef; end

class CommandWindow < Window

  TEXT_NO_SECTION_SELECTED = "Click on the boxes above to set up the according options for the command invokation."
  TEXT_SECTION_SELECTED    = "Set the options according to your needs using the controls at the left of this text."

  private def widgets
    @widgets ||= {
      :self => Gtk::VBox.new,
      :title => {
          :self => Gtk::Label.new,
          :packing => Proc.new { |c, w| c.pack_start(w, FALSE, true) },
          :setup => Proc.new do |w|
              w.text = @clidef.title
              w.set_markup("<span size='xx-large'>#{@clidef.title}</span>") # FIXME use set_attributes instead of markup
              w.set_xalign(0.1)
              #w.set_attributes()
          end,
      },
      :description => {
          :self => Gtk::Label.new,
          :packing => Proc.new { |c, w| c.pack_start(w, false, FALSE) },
          :setup => Proc.new do |w|
              w.text = @clidef.description
              w.set_markup("<span size='large'>#{@clidef.description}\n</span>") # FIXME use set_attributes instead of markup
              w.set_xalign(0.2)
              #w.set_attributes()
          end,
      },
      :scrolled_win => {
          :self => Gtk::ScrolledWindow.new,
          :setup => Proc.new do |scrolled_win|
              scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC) 
          end,
          :cmd_box => {
              :self => Gtk::HBox.new,
              :cmd_btn => {
                  :self => Gtk::Button.new(@clidef.executable),
              },
              :setup => Proc.new { |w| @cmd_box = w }
          },
      },
      :argumentbox => {
        :self => Gtk::HBox.new,
        :scrolled_win_edit => {
          :self => Gtk::ScrolledWindow.new,
          :setup => Proc.new do |scrolled_win|
              scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC) 
              @argedit_box = scrolled_win
          end,
        },
        :scrolled_win_help => {
          :self => Gtk::ScrolledWindow.new,
          :setup => Proc.new do |scrolled_win|
              scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC) 
          end,
          :help => {
              :self => Gtk::TextView.new,
              :setup => Proc.new do |w|
                w.wrap_mode = Gtk::TextTag::WRAP_WORD
                w.editable = false
                @help_buf = w.buffer
                @help_buf.text = TEXT_NO_SECTION_SELECTED
              end,
          },
        },
      },
      :cmdentry => {
          :self => Gtk::Entry.new,
          :packing => Proc.new { |container, w| container.pack_start(w, FALSE, FALSE) },
          :setup => Proc.new do |w|
              w.editable = false # TODO allow entering text, parse the text entered and update visual command line builder accordingly
              @cmdentry = w
          end,
      },
      :btnbox => {
          :self => Gtk::HBox.new,
          :packing => Proc.new { |container, w| container.pack_start(w, FALSE, FALSE) },
          :cancel => {
              :self => Gtk::Button.new('Cancel'),
              :packing => Proc.new { |container, w| container.pack_start(w, FALSE, FALSE) },
              :signals => {
                  'clicked' => Proc.new { Gtk.main_quit }, # FIXME suppress subsequent dialogs
              },
          },
          :exec => {
              :self => Gtk::Button.new('Execute'),
              :packing => Proc.new { |c, w| c.pack_end(w, FALSE, FALSE) },
              :signals => {
                  'clicked' => Proc.new do
                      @window.close
                  end,
              },
              :setup => Proc.new do |btn|
                  @execBtn = btn
              end,
          },
      },
    }
  end # widgets
  
  def initialize(clidef)
    @clidef = clidef
    @button_section_map = {}
    @current_button, @current_section, @current_editor = nil
    super()
    ElementRenderer.cmdwindow = self
    setup_element_wigets
    update_cmdentry
  end

  private def setup_element_wigets
    @clidef.each_section do |s|
        $l.debug "pack display button for section `#{s.title}'"
        b = Gtk::ToggleButton.new
        f = Gtk::Frame.new(s.title)
        b.add(f)
        f.add(s.renderer.display)
        #@button_section_map[b] = s # FIXME in use ?!
        b.signal_connect('toggled') do |w|
          # FIXME extract method
          # FIXME toggled will be signaled to button also when calling active=, so two buttons will receive the toggled signal when "switching" activity from one button to another
          $l.debug "#{w} toggled, now #{w.active? ? "active" : "inactive"}, @current_button is #{@current_button || "nil"}"
          if w.active?
            @current_button.active = false if @current_button
            @current_button = w
            switch_argumentbox(s)
          else
            raise "Invalid state" unless @current_button == w
            @current_button = nil
            switch_argumentbox(nil)
          end
          #refresh_argumentbox
        end
        @cmd_box.pack_start(b)
    end
  end

  def switch_argumentbox(section)
    if section == nil
      @current_section.renderer.editor.hide if @current_section
      self.helptext = TEXT_NO_SECTION_SELECTED 
    elsif section == @current_section
      # TODO update section's editor, but currently not a usecase for this method
    else
      @current_section.renderer.editor.hide if @current_section
      @current_section = section
      e = @current_section.renderer.editor
      @argedit_box.add_with_viewport(e) unless e.parent
      e.show
      self.helptext = TEXT_SECTION_SELECTED
    end
  end

  def update_cmdentry
    @cmdentry.text = @clidef.cmdline
  end

  def helptext=(text)
    @help_buf.text = text || ""
  end

end # class CommandWindow

