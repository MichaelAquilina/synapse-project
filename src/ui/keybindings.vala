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
      NEXT_PANE,
      PREV_PANE,
      EXECUTE,
      EXECUTE_WITHOUT_HIDE,
      NEXT_PAGE,
      PREV_PAGE,
      FIRST_RESULT,
      LAST_RESULT,
      CLEAR_SEARCH_OR_HIDE,
      PASTE,
      PASTE_SELECTION,
      EXIT_SYNAPSE,
      
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
    public string alt_paste { get; set; default = "<Shift>Insert"; }
    public string exit { get; set; default = "<Control>q"; }
    
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
      kcs.set_keycombo_command (keyval, mods, Commands.NEXT_PANE);
      name_to_key_mod (prev_search_type, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.PREV_PANE);
      name_to_key_mod (cancel, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.CLEAR_SEARCH_OR_HIDE);
      name_to_key_mod (paste, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.PASTE);
      name_to_key_mod (alt_paste, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.PASTE_SELECTION);
      name_to_key_mod (exit, out keyval, out mods);
      kcs.set_keycombo_command (keyval, mods, Commands.EXIT_SYNAPSE);
    }
    
    
    /* Clear all non relevant masks like the ones used in IBUS */
    public static uint mod_normalize_mask = Gtk.accelerator_get_default_mod_mask ();

    public Commands get_command_from_eventkey (Gdk.EventKey event)
    {
      uint keyval = event.keyval;
      if (keyval == Gdk.Key.KP_Enter || keyval == Gdk.Key.ISO_Enter)
      {
        keyval = Gdk.Key.Return;
      }
      Gdk.ModifierType mod = event.state & mod_normalize_mask;
      // Synapse.Utils.Logger.log (this, get_name_from_key (keyval, mod));
      return kcs.get_command_for_keycombo (keyval, mod);
    }
    
    public static string? get_name_from_key (uint keyval, Gdk.ModifierType mods)
    {
      mods = mods & mod_normalize_mask;
      if (keyval == Gdk.Key.KP_Enter || keyval == Gdk.Key.ISO_Enter)
      {
        keyval = Gdk.Key.Return;
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
      if (keyval == Gdk.Key.KP_Enter || keyval == Gdk.Key.ISO_Enter)
      {
        keyval = Gdk.Key.Return;
      }
    }
  }
}
