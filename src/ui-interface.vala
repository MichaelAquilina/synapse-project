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
  public class CategoryConfig : ConfigObject
  {
    /* Found in config:  ui->categories */
    public class Category : GLib.Object
    {
      public string name {get; set; default = _("All");}
      public QueryFlags flags {
        get; set; default = QueryFlags.ALL;
      }
      public Category (string name, QueryFlags flags = QueryFlags.ALL)
      {
        this.name = name;
        this.flags = flags;
      }
      
      public Category.from_string (string key)
      {
        string[] nameflags = key.split ("@", 2);
        if (nameflags.length == 2)
        {
          this.name = nameflags[0];
          this.flags = (QueryFlags) nameflags[1].to_uint64 ();
        }
        else if (nameflags.length == 1)
        {
          this.name = nameflags[0];
          this.flags = QueryFlags.ALL;
        }
        // else keep defaults
      }
      
      public static string name_query_to_string (string name, QueryFlags flags)
      {
        return "%s@%u".printf (name, flags);
      }
      
      public string to_string () {
        return "%s@%u".printf (this.name, this.flags);
      }
    }

    public string[] list {
      get; set; default = {
        Category.name_query_to_string ( _("Actions"), QueryFlags.ACTIONS ),
        Category.name_query_to_string ( _("Audio"), QueryFlags.AUDIO ),
        Category.name_query_to_string ( _("Applications"), QueryFlags.APPLICATIONS ),
        Category.name_query_to_string ( _("All"), QueryFlags.ALL ),
        Category.name_query_to_string ( _("Documents"), QueryFlags.DOCUMENTS ),
        Category.name_query_to_string ( _("Images"), QueryFlags.IMAGES ),
        Category.name_query_to_string ( _("Video"), QueryFlags.VIDEO ),
        Category.name_query_to_string ( _("Internet"), QueryFlags.INTERNET | QueryFlags.INCLUDE_REMOTE )
      };
    }
    
    public int default_category_index {
      get; set; default = 3;
    }
    
    public Gee.List<Category> categories {
      get {
        return _categories;
      }
    }
    
    public Gee.Map<QueryFlags, string> labels {
      get {
        return _labels;
      }
    }
    
    public Gee.Map<QueryFlags, string> _labels;
    private Gee.List<Category> _categories;
    construct
    {
      _categories = new Gee.ArrayList<Category> ();
      _labels = new Gee.HashMap<QueryFlags, string> ();
      init_labels ();
      this.update_categories ();
    }
    
    private void init_labels ()
    {
      //_labels.set (QueryFlags.ALL, _("All")); // Do not remove!
      
      _labels.set (QueryFlags.INCLUDE_REMOTE, _("Include remote content"));
      _labels.set (QueryFlags.ACTIONS, _("Actions"));
      _labels.set (QueryFlags.FOLDERS, _("Folders"));
      _labels.set (QueryFlags.AUDIO, _("Audio"));
      _labels.set (QueryFlags.APPLICATIONS, _("Applications"));
      _labels.set (QueryFlags.DOCUMENTS, _("Documents"));
      _labels.set (QueryFlags.IMAGES, _("Images"));
      _labels.set (QueryFlags.VIDEO, _("Video"));
      _labels.set (QueryFlags.INTERNET, _("Internet"));
      //_labels.set (QueryFlags.FILES, _("Files"));
      _labels.set (QueryFlags.UNCATEGORIZED, _("Uncategorized"));
    }
    
    public void update_categories ()
    {
      _categories.clear ();
      foreach (unowned string s in list)
      {
        _categories.add (new Category.from_string (s));
      }
      if (_categories.size < 1)
      {
        //Whooot?! This cannot be true!
        list = {
          Category.name_query_to_string ( _("All"), QueryFlags.ALL )
        };
        update_categories ();
        return;
      }
      if (default_category_index >= _categories.size)
      {
        default_category_index = _categories.size / 2;
      }
    }
    
  }
  public class KeyComboConfig : ConfigObject
  {
    /* Found in config:  ui->shortcuts */
    public enum Commands
    {
      ACTIVATE,
      INVALID_COMMAND,
      SEARCH_DELETE_CHAR,
      NEXT_RESULT,
      PREV_RESULT,
      NEXT_CATEGORY,
      PREV_CATEGORY,
      SWITCH_SEARCH_TYPE,
      EXECUTE,
      EXECUTE_WITHOUT_HIDE,
      NEXT_PAGE,
      PREV_PAGE,
      FIRST_RESULT,
      LAST_RESULT,
      CLEAR_SEARCH_OR_HIDE,
      PASTE,
      
      TOTAL_COMMANDS
    }

    public string activate { get; set; default = "<Control>space"; }
    public string execute { get; set; default = "Return"; }
    public string execute_without_hide { get; set; default = "<Shift>Return"; }
    public string delete_char { get; set; default = "BackSpace"; }
    public string alternative_delete_char { get; set; default = "Delete"; }
    public string next_match { get; set; default = "Down"; }
    public string prev_match { get; set; default = "Up"; }
    public string first_match { get; set; default = "Home"; }
    public string last_match { get; set; default = "End"; }
    public string next_match_page { get; set; default = "Page_Down"; }
    public string prev_match_page { get; set; default = "Page_Up"; }
    public string next_category { get; set; default = "Right"; }
    public string prev_category { get; set; default = "Left"; }
    public string next_search_type { get; set; default = "Tab"; }
    public string prev_search_type { get; set; default = "<Shift>ISO_Left_Tab"; }
    public string cancel { get; set; default = "Escape"; }
    public string paste { get; set; default = "<Control>v"; }
    
    private class KeyComboStorage: GLib.Object
    {
      private class ModCmd : GLib.Object
      {
        public Gdk.ModifierType mods = 0;
        public Commands cmd = 0;
        public ModCmd (Gdk.ModifierType mods, Commands cmd)
        {
          this.cmd = cmd;
          this.mods = mods;
        }
        public static int compare (void* a, void* b)
        {
          return (int)(((ModCmd)a).mods) - (int)(((ModCmd)b).mods);
        }
      }
 
      private Gee.Map<uint, Gee.List<ModCmd>> map;
      
      construct
      {
        map = new Gee.HashMap<uint, Gee.List<ModCmd>> ();
      }
      
      public void set_keycombo_command (uint keyval, Gdk.ModifierType mods, Commands cmd)
      {
        Gee.List<ModCmd> list = null;
        if (!map.has_key (keyval))
        {
          list = new Gee.ArrayList<ModCmd> ();
          map.set (keyval, list);
        }
        else
        {
          list = map.get (keyval);
        }
        list.add (new ModCmd (mods, cmd));
        list.sort (ModCmd.compare);
      }
      
      public Commands get_command_for_keycombo (uint keyval, Gdk.ModifierType mods)
      {
        Gee.List<ModCmd> list = null;
        list = map.get (keyval);
        if (list == null) return Commands.INVALID_COMMAND;
        
        // if mods, and there aren't modded key combo, start with default cmd
        Commands cmd = mods > 0 &&
                       list.size == 1 &&
                       list.get (0).mods == 0 ?
                       list.get (0).cmd : Commands.INVALID_COMMAND;

        // if there are more commands or command is still invalid, search for combo
        if (list.size > 1 || cmd == Commands.INVALID_COMMAND)
        {
          foreach (ModCmd e in list)
          {
            if (e.mods == mods)
            {
              cmd = e.cmd;
              break;
            }
          }
        }
        return cmd;
      }
      
      public void clear ()
      {
        map.clear ();
      }
    }
    
    private KeyComboStorage kcs;
    
    construct
    {
      kcs = new KeyComboStorage ();
      update_bindings ();
    }
    
    public void update_bindings ()
    {
      kcs.clear ();
      uint keyval;
      Gdk.ModifierType mods;

      name_to_key_mod (activate, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.ACTIVATE);
      name_to_key_mod (execute, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.EXECUTE);
      name_to_key_mod (execute_without_hide, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.EXECUTE_WITHOUT_HIDE);
      name_to_key_mod (delete_char, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.SEARCH_DELETE_CHAR);
      name_to_key_mod (alternative_delete_char, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.SEARCH_DELETE_CHAR);
      name_to_key_mod (next_match, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.NEXT_RESULT);
      name_to_key_mod (prev_match, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.PREV_RESULT);
      name_to_key_mod (first_match, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.FIRST_RESULT);
      name_to_key_mod (last_match, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.LAST_RESULT);
      name_to_key_mod (next_match_page, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.NEXT_PAGE);
      name_to_key_mod (prev_match_page, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.PREV_PAGE);
      name_to_key_mod (next_category, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.NEXT_CATEGORY);
      name_to_key_mod (prev_category, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.PREV_CATEGORY);
      name_to_key_mod (next_search_type, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.SWITCH_SEARCH_TYPE);
      name_to_key_mod (prev_search_type, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.SWITCH_SEARCH_TYPE);
      name_to_key_mod (cancel, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.CLEAR_SEARCH_OR_HIDE);
      name_to_key_mod (paste, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.PASTE);
    }
    
    
    /* Clear all non relevant masks like the ones used in IBUS */
    private static uint mod_normalize_mask = Gtk.accelerator_get_default_mod_mask ();

    public Commands get_command_from_eventkey (Gdk.EventKey event)
    {
      uint keyval = event.keyval;
      if (keyval == Gdk.KeySyms.KP_Enter || keyval == Gdk.KeySyms.ISO_Enter)
      {
        keyval = Gdk.KeySyms.Return;
      }
      Gdk.ModifierType mod = event.state & mod_normalize_mask;
      // Synapse.Utils.Logger.log (this, get_name_from_key (keyval, mod));
      return kcs.get_command_for_keycombo (keyval, mod);
    }
    
    public static string? get_name_from_key (uint keyval, Gdk.ModifierType mods)
    {
      mods = mods & mod_normalize_mask;
      if (keyval == Gdk.KeySyms.KP_Enter || keyval == Gdk.KeySyms.ISO_Enter)
      {
        keyval = Gdk.KeySyms.Return;
      }
      unowned string keyname = Gdk.keyval_name (Gdk.keyval_to_lower (keyval));
      if (keyname == null) return null;
      
      string res = "";
      if (Gdk.ModifierType.SHIFT_MASK in mods) res += "<Shift>";
      if (Gdk.ModifierType.CONTROL_MASK in mods) res += "<Control>";
      if (Gdk.ModifierType.MOD1_MASK in mods) res += "<Alt>";
      if (Gdk.ModifierType.MOD2_MASK in mods) res += "<Mod2>";
      if (Gdk.ModifierType.MOD3_MASK in mods) res += "<Mod3>";
      if (Gdk.ModifierType.MOD4_MASK in mods) res += "<Mod4>";
      if (Gdk.ModifierType.MOD5_MASK in mods) res += "<Mod5>";
      if (Gdk.ModifierType.META_MASK in mods) res += "<Meta>";
      if (Gdk.ModifierType.SUPER_MASK in mods) res += "<Super>";
      if (Gdk.ModifierType.HYPER_MASK in mods) res += "<Hyper>";

      res += keyname;
      return res;
    }
    
    public static void name_to_key_mod (string name, out uint keyval, out Gdk.ModifierType mod)
    {
      keyval = 0;
      mod = 0;
      string[] keys = name.split (">");
      foreach (string key in keys)
      {
        if (key[0] != '<')
        {
          keyval = Gdk.keyval_from_name (key);
        }
        else
        {
          switch (key)
          {
            case "<Shift":
              mod |= Gdk.ModifierType.SHIFT_MASK;
              break;
            case "<Control":
              mod |= Gdk.ModifierType.CONTROL_MASK;
              break;
            case "<Alt":
              mod |= Gdk.ModifierType.MOD1_MASK;
              break;
            case "<Super":
              mod |= Gdk.ModifierType.SUPER_MASK;
              break;
            case "<Hyper":
              mod |= Gdk.ModifierType.HYPER_MASK;
              break;
            case "<Meta":
              mod |= Gdk.ModifierType.META_MASK;
              break;
            case "<Mod2":
              mod |= Gdk.ModifierType.MOD2_MASK;
              break;
            case "<Mod3":
              mod |= Gdk.ModifierType.MOD3_MASK;
              break;
            case "<Mod4":
              mod |= Gdk.ModifierType.MOD4_MASK;
              break;
            case "<Mod5":
              mod |= Gdk.ModifierType.MOD5_MASK;
              break;
          }
        }
      }
      if (keyval == Gdk.KeySyms.KP_Enter || keyval == Gdk.KeySyms.ISO_Enter)
      {
        keyval = Gdk.KeySyms.Return;
      }
    }
  }

  public abstract class UIInterface : Object
  {
    /* The target of this abstract class, is to separate model/control from view. */
    /* Each IU must implement this abstract class by translating user input into actions for this class. */
    /* UIs must implement following methods: */

    /**
     * The show method has to show the window to the user.
     */
    public abstract void show ();

    /**
     * The hide method has to hide the window to the user.
     */
    public abstract void hide ();
    
    /**
     * This method needs to:
     * - call show () , when window isn't visible
     * - call hide () , when window is visible
     */
    public abstract void show_hide_with_time (uint32 timestamp);
    
    /**
     * This signal must be emitted from the UI when the button/menu
     * to show settings is pressed.
     */
    public signal void show_settings_clicked ();

    /**
     * Focus match needs to show the user what match is selected.
     * @param index The index of selected match in result list
     * @param match The match selected
     */
    protected abstract void focus_match ( int index, Match? match );
    
    /**
     * Focus action needs to show the user what action is selected.
     * @param index The index of selected action in result list
     * @param match The action selected
     */
    protected abstract void focus_action ( int index, Match? action );
    
    /**
     * This method tells the UI that the match's result list is updated, and a new match is selected.
     * @param matches The new result list
     * @param index The index of selected match in result list
     * @param match The selected match
     */
    protected abstract void update_match_result_list (Gee.List<Match>? matches, int index, Match? match);
    
    /**
     * This method tells the UI that the action's result list is updated, and a new action is selected.
     * @param matches The new result list
     * @param index The index of selected action in result list
     * @param match The selected action
     */
    protected abstract void update_action_result_list (Gee.List<Match>? actions, int index, Match? action);
    
    /**
     * This method sets the visibility of the throbber.
     * @param visible if true, show the trobber, else hide it.
     */
    protected abstract void set_throbber_visible (bool visible);
    
    /**
     * This method is called when the handle_empty staus changes.
     * handle_empty staus defines if the UI can show recent actions
     * when the search string is empty.
     */
    protected virtual void handle_empty_updated () {}
    
    /* -------------------------------------------------------------------- */
    
    /* This strings should be used into the UI */
    protected static string SEARCHING; /* Searching... */
    protected static string NO_RESULTS; /* No results found. */
    protected static string NO_RECENT_ACTIVITIES; /* No recent activities found. */
    protected static string TYPE_TO_SEARCH; /* Type to search */
    protected static string DOWN_TO_SEE_RECENT; /* Press down to see recent */

    /* What this abstract class offer - methods have internal checks to avoid incorrect actions */
    
    /* Get & Set methods for the Match's search string */
    protected string get_match_search () {return search[T.MATCH];}
    protected void set_match_search (string pattern)
    {
      search_with_empty = false;
      search[T.MATCH] = pattern;
      search_for_matches ();
    }
    
    /* Get & Set methods for the Action's search string */
    protected string get_action_search () {return search[T.ACTION];}
    protected void set_action_search (string pattern)
    {
      if (search[T.ACTION] == pattern)
        return;
      search[T.ACTION] = pattern;
      search_for_actions ();
    }
    
    protected void focus_current_match () {focus_match (focus_index[T.MATCH], focus[T.MATCH]);}
    protected void focus_current_action () {focus_action (focus_index[T.ACTION], focus[T.ACTION]);}
    
    /* Getters for results list, and focused Matches and Actions */
    protected Gee.List<Match>? get_action_results () {return results[T.ACTION];}
    protected Gee.List<Match>? get_match_results () {return results[T.MATCH];}
    protected void get_action_focus (out int index, out Match? action) {index = focus_index[T.ACTION]; action = focus[T.ACTION];}
    protected void get_match_focus (out int index, out Match? match) {index = focus_index[T.MATCH]; match = focus[T.MATCH];}
    
    /* This method has to be called when user wants to change query flags */
    protected void update_query_flags (QueryFlags flags)
    {
      if (qf == flags)
        return;
      qf = flags;
      focus_index = {0, 0};
      focus = {null, null};
      results = {null, null};
      search[T.ACTION] = "";
      search_for_matches ();
    }
    
    /* Those methods has to be called when user wants to select first or last match / action */
    protected bool select_first_last_match (bool first)
    {
      return util_select_first_last (first, T.MATCH);
    }
    protected bool select_first_last_action (bool first)
    {
      return util_select_first_last (first, T.ACTION);
    }
    
    /* Those methods moves the selection by "delta" position */
    protected bool move_selection_action (int delta)
    {
      return move_selection (T.ACTION, delta);
    }
    protected bool move_selection_match (int delta)
    {
      return move_selection (T.MATCH, delta);
    }
    
    /* Those methods moves the selection to "index" position */
    protected void set_selection_action (int index)
    {
      set_selection (T.ACTION, index);
    }
    protected void set_selection_match (int index)
    {
      set_selection (T.MATCH, index);
    }
    
    /**
     * This method can be called to reset the search.
     * @param notify if true, visual update matches and actions in the UI
     * @param reset_flags, if true, resets query flags to default (All)
     */
    protected void reset_search (bool notify = true, bool reset_flags = true)
    {
      if (tid != 0)
      {
        Source.remove (tid);
        tid = 0;
      }
      current_cancellable.cancel ();
      partial_result_sent = false;
      search_with_empty = false;
      focus_index = {0, 0};
      focus = {null, null};
      results = {null, null};
      search = {"", ""};
      if (reset_flags)
        qf = QueryFlags.ALL;
      if (notify)
      {
        set_throbber_visible (false);
        update_match_result_list (null, 0, null);
        update_action_result_list (null, 0, null);
      }
    }
    
    /* Returns true if Match search is empty- */
    protected bool is_search_empty ()
    {
      return search[T.MATCH].length == 0;
    }
    
    /* Returns true if user is searching for recent activities with empty search string */
    protected bool is_searching_for_recent ()
    {
      return search_with_empty;
    }
    
    /* Returns true if the status is equal to the starting status of Synapse */
    protected bool is_in_initial_status ()
    {
      return (!search_with_empty) && search[T.MATCH].length == 0 && (results[T.MATCH] == null || results[T.MATCH].size == 0);
    }
    
    /* Returns true if the ui can show recent activities */
    protected bool can_handle_empty ()
    {
      return handle_empty;
    }
    
    /* This method must be called when you want to search for recent activities */
    protected void search_for_empty ()
    {
      search_with_empty = true;
      search_for_matches ();
    }
    
    protected bool has_match_results ()
    {
      return results[T.MATCH] != null && results[T.MATCH].size > 0;
    }
    
    /* This method should be called when user wants to execute the current match */
    /* returns false if there's no valid match/action to execute */
    protected bool execute ()
    {
      if (focus[T.MATCH] == null || focus[T.ACTION] == null)
        return false;
      var match = focus[T.MATCH];
      var action = focus[T.ACTION];
      if (action is SearchProvider)
      {
        search_for_matches (action as SearchProvider);
        return false;
      }
      /* Async execute to avoid freezes when executing a dbus action */
      Timeout.add (30, ()=>{ return _execute (match, action);});
      return true;
    }
    
    public DataSink data_sink { get; construct; }
    public KeyComboConfig key_combo_config { get; construct; }
    public CategoryConfig category_config { get; construct; }
    /* Private section -- You shouldn't need to look after this line */
    
    private const int PARTIAL_TIMEOUT = 100;
    private ResultSet last_result_set;
    private enum T 
    {
      MATCH,
      ACTION
    }
    private int focus_index[2];
    private Match? focus[2];
    private Gee.List<Match>? results[2];
    private QueryFlags qf;
    private string search[2];
    private Cancellable current_cancellable;
    private bool partial_result_sent;
    private bool search_with_empty;
    private bool handle_empty;
    
    private uint tid; //for timer
    
    
    
    static construct
    {
      SEARCHING = _("Searching...");
      NO_RESULTS = _("No results found.");
      NO_RECENT_ACTIVITIES = _("No recent activities found.");
      TYPE_TO_SEARCH = _("Type to search...");
      DOWN_TO_SEE_RECENT = "";
    }
    
    construct
    {
      search_with_empty = false;
      tid = 0;
      partial_result_sent = false;
      current_cancellable = new Cancellable ();
      reset_search (false);
      
      /* Handle ZG plugin to set the handle_empty property*/
      var plugin = data_sink.get_plugin("SynapseZeitgeistPlugin");
      if (plugin != null)
      {
        plugin_registered_handler (plugin);
      }
      data_sink.plugin_registered.connect (plugin_registered_handler);
      update_handle_empty ();
    }
    
    private void plugin_registered_handler (Object plugin)
    {
      // FIXME: expose this as prop of data-sink
      if (plugin.get_type ().name () == "SynapseZeitgeistPlugin")
      {
        plugin.notify["enabled"].connect (update_handle_empty);
        update_handle_empty ();
      }
    }

    private bool util_select_first_last (bool first, T t)
    {
      if (results[t] == null || results[t].size == 0)
        return false;
      int newpos = first ? 0 : results[t].size - 1;
      if (newpos == focus_index[t]) return false;
      focus_index[t] = newpos;
      focus[t] = results[t].get (focus_index[t]);
      if (t == T.MATCH)
      {
        focus_match (focus_index[t], focus[t]);
        search_for_actions ();
      }
      else
        focus_action (focus_index[t], focus[t]);
      return true;
    }
    
    private bool move_selection (T t, int delta)
    {
      if (results[t] == null || results[t].size == 0)
        return false;
      if (delta > 0)
      {
        if (focus_index[t] == results[t].size - 1)
          return false;
        focus_index[t] = int.min (focus_index[t] + delta, results[t].size - 1);
      }
      else
      {
        if (focus_index[t] == 0)
          return false;
        focus_index[t] = int.max (focus_index[t] + delta, 0);
      }
      focus[t] = results[t].get (focus_index[t]);
      if (t == T.MATCH)
      {
        focus_match (focus_index[t], focus[t]);
        search_for_actions ();
      }
      else
        focus_action (focus_index[t], focus[t]);
      return true;
    }
    
    private void set_selection (T t, int index)
    {
      if (results[t] == null || results[t].size == 0 || 
          index < 0 || index >= results[t].size || 
          focus_index[t] == index)
        return;
      focus_index[t] = index;
      focus[t] = results[t].get (focus_index[t]);
      if (t == T.MATCH)
      {
        focus_match (focus_index[t], focus[t]);
        search_for_actions ();
      }
      else
        focus_action (focus_index[t], focus[t]);
    }
    
    private void update_handle_empty ()
    {
      var plugin = data_sink.get_plugin ("SynapseZeitgeistPlugin");
      handle_empty = plugin != null && (plugin as ItemProvider).enabled;
      DOWN_TO_SEE_RECENT = handle_empty ? _("...or press down key to browse recent activities") : "";
      handle_empty_updated ();
    }
    
    private void search_for_matches (SearchProvider? search_provider = null)
    {
      current_cancellable.cancel ();
      current_cancellable = new Cancellable ();
      
      if (search_provider == null) search_provider = data_sink;

      if (!search_with_empty && search[T.MATCH] == "")
      {
        reset_search (true, false);
        return;
      }
      partial_result_sent = false;

      last_result_set = new ResultSet ();
      if (tid == 0)
      {
        tid = Timeout.add (PARTIAL_TIMEOUT, () => {
            tid = 0;
            _send_partial_results (this.last_result_set);
            return false;
        });
      }
      search_provider.search (search[T.MATCH], qf, last_result_set, current_cancellable, _search_ready);
    }
    
    private void _send_partial_results (ResultSet rs)
    {
      /* Search not ready */
      set_throbber_visible (true);
      partial_result_sent = true;
      /* If partial result set is empty
       * Try to match the new string on current focus
       */
      if (focus[T.MATCH] != null && rs.size == 0)
      {
        var matchers = Query.get_matchers_for_query (search[T.MATCH], 0,
            RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (focus[T.MATCH].title))
          {
            focus_match (focus_index[T.MATCH], focus[T.MATCH]);
            return;
          }
        }
      }
      /* String didn't match, get partial results */
      focus_index[T.MATCH] = 0;
      results[T.MATCH] = rs.get_sorted_list ();
      if (results[T.MATCH].size > 0)
      {
        focus[T.MATCH] = results[T.MATCH].first();
      }
      else
      {
        focus[T.MATCH] = null;
      }
      /* If we are here, we are searching for Matches */
      update_match_result_list (results[T.MATCH], focus_index[T.MATCH], focus[T.MATCH]);
      /* Send also actions */
      search_for_actions ();
    }
    
    private void _search_ready (GLib.Object? obj, AsyncResult res)
    {
      try
      {
        results[T.MATCH] = (obj as SearchProvider).search.end (res);
        /* Do not write code before this line */

        if (!partial_result_sent)
        {
          /* reset current focus */
          focus[T.MATCH] = null;
          focus_index[T.MATCH] = 0;
        }
        /* Search not cancelled and ready */
        set_throbber_visible (false);
        if (tid != 0)
        {
          Source.remove (tid);
          tid = 0;
        }
        if (results[T.MATCH].size > 0)
        {
          if (focus[T.MATCH] != null)
          {
            /* The magic is here, remove che current focus from the new list */
            /* and then reinsert it in the current focus position */
            int i = results[T.MATCH].index_of (focus[T.MATCH]);
            if (i > 0)
            {
              focus_index[T.MATCH] = i;
            }
            else
            {
              // cannot find the item! That's impossible! Btw, select the first item
              focus_index[T.MATCH] = 0;
              focus[T.MATCH] = results[T.MATCH].first ();
            }
          }
          else
          {
            focus[T.MATCH] = results[T.MATCH].get (focus_index[T.MATCH]);
          }
        }
        else
        {
          focus[T.MATCH] = null;
          focus_index[T.MATCH] = 0;
        }
        /* Send also actions */
        search_for_actions ();
        update_match_result_list (results[T.MATCH], focus_index[T.MATCH], focus[T.MATCH]);
      }
      catch (SearchError err)
      {
        // most likely cancelled
      }
    }
    
    private void search_for_actions ()
    {
      if (focus[T.MATCH] == null)
      {
        update_action_result_list (null, 0, null);
        return;
      }
      results[T.ACTION] = data_sink.find_actions_for_match (focus[T.MATCH], search[T.ACTION], qf);
      if (results[T.ACTION].size > 0)
      {
        focus[T.ACTION] = results[T.ACTION].first();
      }
      else
      {
        focus[T.ACTION] = null;
      }
      focus_index[T.ACTION] = 0;
      update_action_result_list (results[T.ACTION], focus_index[T.ACTION], focus[T.ACTION]);
    }
    
    private bool _execute (Match match, Match action)
    {
      action.execute (match);
      return false;
    }
  }
}
