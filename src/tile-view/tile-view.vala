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
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;

namespace UI.Widgets
{
  public class TileView: EventBox
  {
    private List<Tile> tiles = new List<Tile> ();
    private VBox box = new VBox (false, 0);

    public int icon_size { get; construct set; default = 48; }

    protected int selected_index = -1;

    public TileView ()
    {
      GLib.Object (can_focus: true, visible_window: false);

      this.button_press_event.connect (this.on_button_press);
      this.key_press_event.connect (this.on_key_press);
      box.show ();
      this.add (box);

      style_updated ();
    }

    public virtual void append_tile (AbstractTileObject tile_obj)
    {
      Tile tile = new Tile (tile_obj, this.icon_size);
      tile.owner = this;
      tile.active_changed.connect (this.on_tile_active_changed);
      tile.size_allocate.connect (this.on_tile_size_allocated);
      tile.show ();

      tiles.append (tile);

      box.pack_start (tile, false, false, 0);
    }

    public virtual void remove_tile (AbstractTileObject tile_obj)
    {
      unowned Tile tile = null;
      foreach (unowned Tile t in tiles)
      {
        if (t.owned_object == tile_obj)
        {
          tile = t;
          break;
        }
      }

      if (tile == null)
      {
        warning ("Container does not own this AbstractTileObject!");
        return;
      }

      if (selected_index == tiles.index (tile))
      {
        clear_selection ();
      }

      tile.hide ();
      tile.active_changed.disconnect (this.on_tile_active_changed);
      tile.size_allocate.disconnect (this.on_tile_size_allocated);
      tile.owner = null;

      box.remove (tile);
      tiles.remove (tile);
    }

    public List<unowned AbstractTileObject> get_tiles ()
    {
      var result = new List<unowned AbstractTileObject> ();

      foreach (unowned Tile t in tiles)
      {
        result.prepend (t.owned_object);
      }
      result.reverse ();

      return result;
    }

    public void clear ()
    {
      var tiles_copy = this.get_tiles ();
      foreach (unowned AbstractTileObject to in tiles_copy)
      {
        this.remove_tile (to);
      }
    }

    public virtual void clear_selection ()
    {
      if (0 <= selected_index < tiles.length ())
      {
        tiles.nth_data (selected_index).set_selected (false);
      }

      selected_index = -1;
    }

    public virtual AbstractTileObject? get_current_tile ()
    {
      if (0 <= selected_index < tiles.length ())
      {
        return tiles.nth_data (selected_index).owned_object;
      }

      return null;
    }

    private bool changing_style = false;

    protected override void style_updated ()
    {
      /*if (changing_style) return;

      changing_style = true;
      base.style_updated ();
      unowned Widget p = this.get_parent ();
      p.modify_bg (StateType.NORMAL, style.@base[StateType.NORMAL]);
      changing_style = false;*/
    }

    public virtual void on_tile_active_changed (Tile tile)
    {
      tile.owned_object.active_changed ();

      foreach (unowned Tile t in tiles)
      {
        t.update_state ();
      }
    }

    public virtual void on_tile_size_allocated (Gtk.Widget w, Gtk.Allocation alloc)
    {
      Tile tile = w as Tile;
      ScrolledWindow? scroll = null;

      scroll = this.get_parent () == null ? 
        null : this.get_parent ().get_parent () as ScrolledWindow;
      if (scroll == null)
      {
        return;
      }

      if (tiles.index (tile) != selected_index)
      {
        return;
      }

      var va = Gdk.Rectangle ();
      va.x = 0;
      va.y = (int) scroll.get_vadjustment ().get_value ();
      va.width = alloc.width;
      va.height = this.get_parent ().get_allocated_height ();

      var va_region = new Cairo.Region.rectangle (va);
      if (va_region.contains_rectangle ((Cairo.RectangleInt)alloc) != Cairo.RegionOverlap.IN)
      {
        double delta = 0.0;
        if (alloc.y + alloc.height > va.y + va.height)
        {
          delta = alloc.y + alloc.height - (va.y + va.height);
          delta += this.style.ythickness * 2;
        }
        else if (alloc.y < va.y)
        {
          delta = alloc.y - va.y;
        }

        scroll.get_vadjustment ().set_value (va.y + delta);
        this.queue_draw ();
      }
    }

    protected bool on_button_press (Gdk.EventButton event)
    {
      this.has_focus = true;

      clear_selection ();

      for (int i=0; i<tiles.length (); i++)
      {
        unowned Tile t = tiles.nth_data (i);
        Gtk.Allocation alloc;
        t.get_allocation (out alloc);
        var region = new Cairo.Region.rectangle ((Cairo.RectangleInt)alloc);
        if (region.contains_point ((int)event.x, (int)event.y))
        {
          this.select (i);
          break;
        }
      }

       this.queue_draw ();

      return false;
    }

    protected bool on_key_press (Gdk.EventKey event)
    {
      int index = selected_index;

      switch (event.keyval)
      {
        case Gdk.Key.Up:
        case Gdk.Key.KP_Up:
        case Gdk.Key.uparrow:
          index--;
          break;
        case Gdk.Key.Down:
        case Gdk.Key.KP_Down:
        case Gdk.Key.downarrow:
          index++;
          break;
      }

      index = index.clamp (0, (int) tiles.length () - 1);

      if (index != selected_index)
      {
        clear_selection ();
        this.select (index);
        return true;
      }

      return false;
    }

    public void select (int index)
    {
      if (0 <= index < tiles.length ())
      {
        selected_index = index;
        tiles.nth_data (index).set_selected (true);
      }
      else
      {
        clear_selection ();
      }

      if (this.get_parent () != null && this.get_parent ().get_realized ())
      {
        this.get_parent ().queue_draw ();
      }

      this.queue_resize ();
    }
  }
}
