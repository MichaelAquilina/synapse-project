/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Cairo;
using Gee;

namespace Synapse
{
  public class SettingsWindow : Gtk.Window
  {
    class PluginTileObject: UI.Widgets.AbstractTileObject
    {
      public DataSink.PluginRegistry.PluginInfo pi { get; construct set; }
      public PluginTileObject (DataSink.PluginRegistry.PluginInfo info)
      {
        GLib.Object (name: info.title,
                     description: info.description,
                     icon: info.icon_name,
                     pi: info);
      }

      construct
      {
        sub_description_title = "Status"; // FIXME: i18n

        add_button_tooltip = "Enable this plugin"; // FIXME: i18n
        remove_button_tooltip = "Disable this plugin"; // FIXME: i18n
      }

      public void update_state (bool enabled)
      {
        this.enabled = enabled;

        if (!enabled)
        {
          sub_description_text = "Disabled"; // i18n!
        }
        else
        {
          sub_description_text = "Enabled"; // i18n!
        }
      }
    }
    
    private struct Theme
    {
      string name;
      string description;
      Type tclass;
    }

    private string selected_theme;
    private Gee.Map<string, Theme?> themes;
    private bool autostart;
    private unowned DataSink data_sink;
    private Gtk.ListStore model;

    public SettingsWindow (DataSink data_sink)
    {
      this.title = "Synapse - Settings"; //TODO: i18n
      this.data_sink = data_sink;
      this.set_position (WindowPosition.CENTER);
      this.set_size_request (500, 450);
      this.resizable = false;
      this.delete_event.connect (this.hide_on_delete);
      init_settings ();
      build_ui ();
      
      this.tile_view.map.connect (this.init_plugin_tiles);
    }

    private void init_themes ()
    {
      themes = new Gee.HashMap<string, Theme?>();
      themes.set ("Default",
                   Theme(){
                     name = "Default", //i18n
                     description = "", //i18n
                     tclass = typeof (SynapseWindow)
                   });
      themes.set ("Mini",
                   Theme(){
                     name = "Mini", //i18n
                     description = "", //i18n
                     tclass = typeof (SynapseWindowMini)
                   });

      // TODO: read from gconf the selected one
#if UI_MINI
      selected_theme = "Mini";
#else
      selected_theme = "Default";
#endif
    }
    
    private void init_plugin_tiles ()
    {
      tile_view.clear ();
      var arr = new Gee.ArrayList<DataSink.PluginRegistry.PluginInfo> ();
      arr.add_all (DataSink.PluginRegistry.get_default ().get_plugins ());
      arr.sort ((a, b) => 
      {
        unowned DataSink.PluginRegistry.PluginInfo p1 =
          (DataSink.PluginRegistry.PluginInfo) a;
        unowned DataSink.PluginRegistry.PluginInfo p2 =
          (DataSink.PluginRegistry.PluginInfo) b;
        return strcmp (p1.title, p2.title);
      });
      
      foreach (var pi in arr)
      {
        var tile = new PluginTileObject (pi);
        tile_view.append_tile (tile);
        tile.update_state (data_sink.is_plugin_enabled (pi.plugin_type));
        
        tile.active_changed.connect ((tile_obj) =>
        {
          PluginTileObject pto = tile_obj as PluginTileObject;
          pto.update_state (!tile_obj.enabled);
          data_sink.set_plugin_enabled (pto.pi.plugin_type, tile_obj.enabled);
        });
      }
    }
    
    private void init_general_options ()
    {
      autostart = false;
    }

    private void init_settings ()
    {
      init_themes ();
      init_general_options ();
    }
    
    private UI.Widgets.TileView tile_view;

    private static string? get_name_from_key (uint keyval, Gdk.ModifierType mods)
    {
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

    private void build_ui ()
    {
      var main_vbox = new VBox (false, 6);
      main_vbox.border_width = 4;
      this.add (main_vbox);
      
      var tabs = new Gtk.Notebook ();
      var general_tab = new VBox (false, 4);
      general_tab.border_width = 5;
      var plugin_tab = new VBox (false, 4);
      plugin_tab.border_width = 5;
      main_vbox.pack_start (tabs);
      tabs.append_page (general_tab, new Label ("General"));
      tabs.append_page (plugin_tab, new Label ("Plugins"));
      
      /* General Tab */
      HBox row;
      row = new HBox (false, 5);

      row.pack_start (new Label ("Select Theme:"), false, false);
      row.pack_start (build_theme_combo (), false, false);
      general_tab.pack_start (row, false, false);

      // keybinding treeview
      Gtk.TreeView treeview = new Gtk.TreeView ();
      general_tab.pack_start (treeview, false, false, 0);
      model = new Gtk.ListStore (2, typeof (string), typeof (string));
      treeview.set_model (model);

      Gtk.CellRenderer ren;
      Gtk.TreeViewColumn col;
      ren = new CellRendererText ();
      col = new TreeViewColumn.with_attributes ("Action", ren, "text", 0); // FIXME: i18n
      treeview.append_column (col);

      ren = new CellRendererAccel ();
      (ren as CellRendererAccel).editable = true;
      (ren as CellRendererAccel).accel_mode = Gtk.CellRendererAccelMode.OTHER;
      (ren as CellRendererAccel).accel_edited.connect (
        (a, path, accel_key, accel_mods, keycode) =>
      {
        string? keyname = get_name_from_key (accel_key, accel_mods);
        this.set_keybinding (keyname ?? "");
      });
      (ren as CellRendererAccel).accel_cleared.connect (
        (a, path) =>
      {
        this.set_keybinding ("");
      });
      col = new TreeViewColumn.with_attributes ("Shortcut", ren, "text",1);
      treeview.append_column (col);

      // add the actual item
      Gtk.TreeIter iter;
      model.append (out iter);
      model.set (iter, 0, "Activate");

      /* Plugin Tab */
      var scroll = new Gtk.ScrolledWindow (null, null);
      scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
      tile_view = new UI.Widgets.TileView ();
      tile_view.show_all ();
      scroll.add_with_viewport (tile_view);
      scroll.show ();

      plugin_tab.pack_start (scroll);

      /* Button */
      var bbox = new Gtk.HButtonBox ();
      bbox.set_layout (Gtk.ButtonBoxStyle.END);
      var close_button = new Gtk.Button.from_stock (Gtk.STOCK_CLOSE);
      close_button.clicked.connect (() => { this.hide (); });
      bbox.pack_start (close_button);
      
      main_vbox.pack_start (bbox, false);
      
      main_vbox.show_all ();
    }
    
    public signal void keybinding_changed (string keybinding);
    
    public void set_keybinding (string key, bool emit = true)
    {
      if (model != null)
      {
        Gtk.TreeIter iter;
        if (model.get_iter_first (out iter))
        {
          model.set (iter, 1, key != "" ? key : "Disabled");
        }
      }
      if (emit) keybinding_changed (key);
    }

    private ComboBox build_theme_combo ()
    {
      var cb_themes = new ComboBox.text ();
      /* Set the model */                  /* key */      /* Label */
      var theme_list = new ListStore (2, typeof(string), typeof(string));
      cb_themes.clear ();
      cb_themes.set_model (theme_list);
      /* Set the renderer only for the Label */
      var ctxt = new CellRendererText();
      cb_themes.pack_start (ctxt, true);
      cb_themes.set_attributes (ctxt, "text", 1);
      /* Pack data into the model and select current theme */
      TreeIter iter;
      foreach (Gee.Map.Entry<string,Theme?> e in themes.entries)
      {
        theme_list.append (out iter);
        theme_list.set (iter, 0, e.key, 1, e.value.name);
        if (e.key == selected_theme)
          cb_themes.set_active_iter (iter);
      }
      /* Listen on value changed */
      cb_themes.changed.connect (() => {
        TreeIter active_iter;
        cb_themes.get_active_iter (out active_iter);
        theme_list.get (active_iter, 0, out selected_theme);
        theme_selected (get_current_theme ());
      });
      
      return cb_themes;
    }
    public Type get_current_theme ()
    {
      return themes.get(selected_theme).tclass;
    }

    public signal void theme_selected (Type theme);
  }
}
