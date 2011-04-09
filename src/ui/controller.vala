/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 * Copyright (C) 2010 Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

using Gee;

namespace Synapse.Gui
{
  public class Controller : IController, Object
  {
    /* Construct properties */
    public DataSink data_sink { get; construct set; }
    public KeyComboConfig key_combo_config { get; construct set; }
    public CategoryConfig category_config { get; construct set; }
    
    protected IModel model;
    private QueryFlags qf;
    
    protected IView view = null;
    public void set_view (Type view_type)
    {
      if (!view_type.is_a (typeof (IView))) return;
      if (this.view != null) this.view.vanish ();
      this.view = GLib.Object.new (view_type, "model", this.model,
                                              "controller", this) as IView;
      //reset_search (true, true); //TODO!!
      this.view.vanished.connect (()=>{
        //reset_search (true, true);
      });
    }
    
    /* Events called by View */
    
    /* key_press_event should be fired on key press */
    public void key_press_event (Gdk.EventKey event)
    {
      /* Check for commands */
      KeyComboConfig.Commands command = 
        this.key_combo_config.get_command_from_eventkey (event);
      
      if (this.fetch_command (command)) return;
      /* Check for text input */
      im_context.filter_keypress (event);
    }
    
    /* category_changed_event should be fired ie when user clicks on a category */
    public void category_changed_event (int category_index)
    {
      if (category_index < 0 || category_index >= category_config.categories.size)
      {
        /* WTF! Invalid index, update view with the right category. */
        view.update_selected_category ();
        return;
      }
      if (category_index == model.selected_category) return;

      model.selected_category = category_index;
      model.query [SearchingFor.ACTIONS] = "";
      model.query [SearchingFor.TARGETS] = "";
      qf = this.category_config.categories.get (category_index).flags;
      
      // TODO: start the new search!
    }

    
    /* selected_index_changed should be fired when users clicks on an item in the list */
    /* Model.focus[Model.searching_for] will be changed */
    public void selected_index_changed_event (int focus_index)
    {
      if (!model.has_results ()) return;
      if (focus_index < 0) focus_index = 0;
      if (focus_index >= model.results[model.searching_for].size)
        focus_index = model.results[model.searching_for].size - 1;

      model.set_actual_focus (focus_index);
      switch (model.searching_for)
      {
        case SearchingFor.SOURCES:
          view.update_focused_source ();
          break;
        case SearchingFor.ACTIONS:
          view.update_focused_action ();
          break;
        default: //case SearchingFor.TARGETS:
          view.update_focused_target ();
          break;
      }
    }
    
    /* Events called by Synapse-Main */
    
    /* Shows or hide the View */
    public void summon_or_vanish ()
    {
      if (this.view == null) return;
      this.view.summon_or_vanish ();
    }
    
    /* End interface implementation */
    protected Gtk.IMMulticontext im_context;
    
    construct 
    {
      /* Initialize model */
      this.model = new Model ();
      //this.init_search ();
     
      /* Typing handle */
      im_context = new Gtk.IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (search_add_delete_char);
      im_context.focus_in ();
    }
    
    protected void execute (bool hide = true)
    {
      if (this.model.focus[SearchingFor.SOURCES].value == null) return;
      if (this.model.focus[SearchingFor.ACTIONS].value == null) return;

      this.model.focus[SearchingFor.ACTIONS].value.execute_with_target (
                              this.model.focus[SearchingFor.SOURCES].value,
                              this.model.focus[SearchingFor.TARGETS].value);

      if (hide)
      {
        this.view.vanish ();
        // TODO: reset!
      }
      else
      {
        // TODO: and now?!
      }
    }
    
    protected void search_add_delete_char (string? newchar = null)
    {
      if (newchar == null)
      {
        // delete
        if (model.query[model.searching_for] == "") return;
        model.query[model.searching_for] = 
          Synapse.Utils.remove_last_unichar (model.query[model.searching_for]);
      }
      else
      {
        // add
        model.query[model.searching_for] = 
          model.query[model.searching_for] + newchar;
      }
      switch (model.searching_for)
      {
        case SearchingFor.SOURCES:
          //TODO: start search
          break;
        case SearchingFor.ACTIONS:
          //TODO: start search
          break;
        default: //case SearchingFor.TARGETS:
          //TODO : start new search for targets
          break;
      }
    }
    
    protected virtual void clear_search_or_hide_pressed ()
    {
      view.vanish (); //TODO
    }
    
    protected virtual bool fetch_command (KeyComboConfig.Commands command)
    {
      if (command != command.INVALID_COMMAND)
      {
        switch (command)
        {
          case KeyComboConfig.Commands.EXECUTE_WITHOUT_HIDE:
            execute (false);
            break;
          case KeyComboConfig.Commands.EXECUTE:
            execute (true);
            break;
          case KeyComboConfig.Commands.SEARCH_DELETE_CHAR:
            search_add_delete_char ();
            break;
          case KeyComboConfig.Commands.CLEAR_SEARCH_OR_HIDE:
            clear_search_or_hide_pressed ();
            break;
          case KeyComboConfig.Commands.PREV_CATEGORY:
            
            break;
          case KeyComboConfig.Commands.NEXT_CATEGORY:
            
            break;
          case KeyComboConfig.Commands.FIRST_RESULT:
            selected_index_changed_event (0);
            break;
          case KeyComboConfig.Commands.LAST_RESULT:
            if (model.has_results ())
              selected_index_changed_event (this.model.results[this.model.searching_for].size - 1);
            break;
          case KeyComboConfig.Commands.PREV_RESULT:
            if (view.is_list_visible () && this.model.focus[this.model.searching_for].key == 0)
            {
              view.set_list_visible (false);
              break;
            }
            selected_index_changed_event (this.model.focus[this.model.searching_for].key - 1);
            break;
          case KeyComboConfig.Commands.PREV_PAGE:
            if (view.is_list_visible () && this.model.focus[this.model.searching_for].key == 0)
            {
              view.set_list_visible (false);
              break;
            }
            selected_index_changed_event (this.model.focus[this.model.searching_for].key - this.RESULTS_PER_PAGE);
            break;
          case KeyComboConfig.Commands.NEXT_RESULT:
            if (!view.is_list_visible ())
            {
              view.set_list_visible (true);
              break;
            }
            selected_index_changed_event (this.model.focus[this.model.searching_for].key + 1);
            break;
          case KeyComboConfig.Commands.NEXT_PAGE:
            if (!view.is_list_visible ())
            {
              view.set_list_visible (true);
              break;
            }
            selected_index_changed_event (this.model.focus[this.model.searching_for].key + this.RESULTS_PER_PAGE);
            break;
          case KeyComboConfig.Commands.SWITCH_SEARCH_TYPE:
            switch (this.model.searching_for)
            {
              case SearchingFor.SOURCES:
                if (this.model.focus[SearchingFor.SOURCES].value != null)
                {
                  this.model.searching_for = SearchingFor.ACTIONS;
                  view.update_searching_for ();
                }
                break;
              case SearchingFor.ACTIONS:
                if (this.model.focus[SearchingFor.ACTIONS].value != null &&
                    this.model.focus[SearchingFor.ACTIONS].value.needs_target ())
                {
                  this.model.searching_for = SearchingFor.TARGETS;
                }
                else
                {
                  this.model.searching_for = SearchingFor.SOURCES;
                }
                view.update_searching_for ();
                break;
              default: //TARGETS
                this.model.searching_for = SearchingFor.SOURCES;
                view.update_searching_for ();
                break;
            }
            break;
          case KeyComboConfig.Commands.ACTIVATE:
            //TODO: reset
            this.view.vanish ();
            break;
          case KeyComboConfig.Commands.PASTE:
            var display = Gdk.Screen.get_default ().get_display ();
            var clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
            // Get text from clipboard
            string text = clipboard.wait_for_text ();
            if (text != null && text != "")
            {
              search_add_delete_char (text);
            }
            break;
        }
        return true;
      }
      return false;
    }
    
    /* ------------ Search Engine here ---------------- */
    
    
  }
}
