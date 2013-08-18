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
  public class Tile: Table
  {
    private Button add_remove_button;
    private Box button_box;

    private Label title;
    private Image tile_image;
    private WrapLabel description;
    private Label sub_description;
    private Image add_image;
    private Image remove_image;

    private int icon_size;

    public unowned TileView owner { get; set; }
    public AbstractTileObject owned_object { get; private set; }
    public bool last { get; private set; }

    public signal void active_changed ();

    public Tile (AbstractTileObject obj, int icon_size)
    {
      GLib.Object (n_rows: 3, n_columns: 3, homogeneous: false);

      IconSize isz = IconSize.SMALL_TOOLBAR;
      add_image = new Image.from_stock (obj.add_button_stock, isz);
      remove_image = new Image.from_stock (obj.remove_button_stock, isz);
      
      owned_object = obj;
      owned_object.icon_updated.connect (this.set_image);
      owned_object.text_updated.connect (this.set_text);
      owned_object.buttons_updated.connect (this.update_buttons);
      owned_object.notify["enabled"].connect (this.update_state);

      this.icon_size = icon_size;

      build_tile ();
    }

    private void build_tile ()
    {
      this.row_spacing = 1;
      this.column_spacing = 5;

      tile_image = new Image ();
      tile_image.margin_left = 5;
      tile_image.margin_top = 5;
      tile_image.margin_bottom = 10;

      tile_image.yalign = 0.0f;
      this.attach (tile_image, 0, 1, 0, 3,
                   AttachOptions.SHRINK,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 0);

      title = new Label ("");
      title.xalign = 0.0f;
      title.margin_top = 5;
      this.attach (title, 1, 3, 0, 1,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 0);
      title.show ();

      description = new WrapLabel ();
      this.attach (description, 1, 3, 1, 2,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 0);
      description.show ();

      sub_description = new Label ("");
      sub_description.xalign = 0.0f;
      this.attach (sub_description, 1, 2, 2, 3,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 4);
      sub_description.show ();

      set_text ();

      button_box = new HBox (false, 3);
      button_box.margin_bottom = 5;

      add_remove_button = new Button ();
      // FIXME: could cause leak!
      add_remove_button.clicked.connect (() => { this.active_changed (); });

      update_buttons ();

      this.attach (button_box, 2, 3, 2, 3,
                   AttachOptions.SHRINK,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 0);

      this.show ();
      update_state ();
    }
    
    protected override void realize ()
    {
      this.set_has_window (false);
      this.set_window (this.get_parent ().get_window ());
      base.realize ();
    }

    protected override bool draw (Cairo.Context cr)
    {
      Gtk.Allocation allocation;
      this.get_allocation (out allocation);

      var context = this.get_style_context ();

      if (this.get_state () == StateType.SELECTED)
      {
        context.render_background (cr, 0, 0, allocation.width, allocation.height);
      }

      if (!last)
      {
        context.save ();
        // this gives us a lighter stroke
        context.add_class (Gtk.STYLE_CLASS_SEPARATOR);
        context.render_line (cr, 0, allocation.height - 1,
          allocation.width, allocation.height - 1);
        context.restore ();
      }

      return base.draw (cr);
    }

    public void update_state ()
    {
      bool enabled = owned_object.enabled;
      bool is_selected = this.get_state () == StateType.SELECTED;
      bool sensitive = enabled || (!enabled && is_selected);

      set_image ();

      title.set_sensitive (sensitive);
      description.set_sensitive (sensitive);
      description.wrap = is_selected;
      sub_description.set_visible (is_selected);

      add_remove_button.set_image (enabled ? remove_image : add_image);
      add_remove_button.set_tooltip_markup (enabled ?
        owned_object.remove_button_tooltip : owned_object.add_button_tooltip);
    }

    public void set_selected (bool selected)
    {
      this.set_state_flags (selected ? StateFlags.SELECTED : StateFlags.NORMAL, true);

      if (selected)
      {
        button_box.show_all ();
      }
      else
      {
        button_box.hide ();
      }

      // need to reset those to prevent multiple overlapping backgrounds
      button_box.set_state_flags (StateFlags.NORMAL, true);
      tile_image.set_state_flags (StateFlags.NORMAL, true);
      description.set_state_flags (StateFlags.NORMAL, true);
      sub_description.set_state_flags (StateFlags.NORMAL, true);
      title.set_state_flags (StateFlags.NORMAL, true);

      this.update_state ();
      this.queue_resize ();
    }

    private void set_image ()
    {
      Gdk.Pixbuf pixbuf = null;
      if (owned_object.force_pixbuf != null)
      {
        pixbuf = owned_object.force_pixbuf;
        if (pixbuf.get_width () != icon_size 
          || pixbuf.get_height () != icon_size)
        {
          pixbuf = pixbuf.scale_simple (icon_size, icon_size,
                                        Gdk.InterpType.BILINEAR);
        }
      }
      else
      {
        try
        {
          Gdk.Pixbuf temp_pb;
          unowned IconTheme it = IconTheme.get_default ();
          try
          {
            temp_pb = it.load_icon (owned_object.icon,
                                    icon_size,
                                    IconLookupFlags.FORCE_SIZE);
          }
          catch (GLib.Error err)
          {
            temp_pb = it.load_icon (Gtk.Stock.FILE,
                                    icon_size,
                                    IconLookupFlags.FORCE_SIZE);
          }
          pixbuf = temp_pb.copy ();
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      tile_image.set_sensitive (owned_object.enabled); // monochromatize

      tile_image.set_from_pixbuf (pixbuf);
      tile_image.show ();
    }

    private void set_text ()
    {
      title.set_markup (Markup.printf_escaped ("<b>%s</b>", owned_object.name));
      description.set_text (owned_object.description);

      if (owned_object.sub_description_title != "" &&
          owned_object.sub_description_text != "")
      {
        sub_description.set_markup (Markup.printf_escaped (
          "<small><b>%s</b> <i>%s</i></small>",
            owned_object.sub_description_title,
            owned_object.sub_description_text
          )
        );
      }
    }

    private void update_buttons ()
    {
      List<weak Widget> children = button_box.get_children ();
      foreach (weak Widget w in children)
      {
        button_box.remove (w);
      }

      foreach (weak Widget w in owned_object.get_extra_buttons ())
      {
        button_box.pack_start (w, false, false, 0);
        w.show ();
      }

      if (owned_object.show_action_button && add_remove_button != null)
      {
        button_box.pack_start (add_remove_button, false, false, 0);
      }
    }
  }
}
