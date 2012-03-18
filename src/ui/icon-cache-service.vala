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
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *						 Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

using Gee;
namespace Synapse.Gui
{
  public class IconCacheService : GLib.Object
  {
    private static IconCacheService instance = null;
    
    public static IconCacheService get_default ()
    {
      return instance ?? new IconCacheService ();
    }
    
    private IconCacheService ()
    {
      
    }
    
    private class PixbufInfo : GLib.Object
    {
      private Gdk.Pixbuf _pixbuf;
      public Gdk.Pixbuf pixbuf {
        get {
          this.last_time_used = time_t ();
          return this._pixbuf;
        }
      }
      public time_t last_time_used;
      //name?!
      public PixbufInfo (Gdk.Pixbuf pixbuf)
      {
        this._pixbuf = pixbuf;
        //this.last_time_used = time_t ();
      }
    }
    
    private Gee.Map<string, PixbufInfo> map;
    private Gtk.IconTheme theme;
    construct
    {
      instance = this;
      this.theme = Gtk.IconTheme.get_default ();
      this.theme.changed.connect (this.clear_cache);
      map = new Gee.HashMap<string, PixbufInfo> ();
    }
    
    public void clear_cache ()
    {
      map.clear ();
      Synapse.Utils.Logger.debug (this, "Icon Cache cleared.");
    }
    
    public void reduce_cache ()
    {
      Gee.List<string> keys = new Gee.ArrayList<string> ();
      keys.add_all (map.keys);
      int i = 0;
      // remove all non-themed icons
      foreach (var key in keys)
      {
        if (key.has_prefix ("/") || key.has_prefix ("~"))
        {
          map.unset (key);
          i++;
        }
      }
      keys.clear ();
      Synapse.Utils.Logger.debug (this, "Cache freed/size: %d/%d", i, map.size);
    }
    
    public Gdk.Pixbuf? get_icon (string name, int pixel_size)
    {
      if (name == "") return null;
      string key = "%s|%d".printf (name,pixel_size);
      PixbufInfo? info = map.get (key);
      if (info == null)
      {
        var pixbuf = get_pixbuf (name, pixel_size);
        if (pixbuf == null) pixbuf = get_pixbuf ("unknown", pixel_size);
        if (pixbuf == null) return null;
        info = new PixbufInfo (pixbuf);
        map.set (key, info);
      }
      return info.pixbuf;
    }
    
    private Gdk.Pixbuf? get_pixbuf (string name, int pixel_size)
    {
      try {
        var icon = GLib.Icon.new_for_string(name);
        if (icon == null) return null;

        Gtk.IconInfo iconinfo = this.theme.lookup_by_gicon (icon, pixel_size, Gtk.IconLookupFlags.FORCE_SIZE);
        if (iconinfo == null) return null;

        Gdk.Pixbuf icon_pixbuf = iconinfo.load_icon ();
        if (icon_pixbuf != null) return icon_pixbuf;
      } catch (Error e) { }
      return null;
    }
  }
}

