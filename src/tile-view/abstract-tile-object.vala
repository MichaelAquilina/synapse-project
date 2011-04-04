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

namespace UI.Widgets
{
  public abstract class AbstractTileObject: Object
  {
    public signal void icon_updated ();
    public signal void text_updated ();
    public signal void buttons_updated ();
    public virtual signal void active_changed () {}

    private List<Gtk.Button> extra_buttons = new List<Gtk.Button> ();
    public List<weak Gtk.Button> get_extra_buttons ()
    {
      return extra_buttons.copy ();
    }

    private string _icon;
    public string icon
    {
      get
      {
        if (_icon == null) _icon = "";
        return _icon;
      }
      set
      {
        if (_icon == value) return;
        // clear forced pixbuf
        if (force_pixbuf != null) force_pixbuf = null;

        _icon = value;
        icon_updated ();
      }
    }

    private Gdk.Pixbuf? _force_pixbuf;
    public Gdk.Pixbuf force_pixbuf
    {
      get 
      {
        return _force_pixbuf;
      }
      set
      {
        if (_force_pixbuf == value) return;
        _force_pixbuf = value;
        icon_updated ();
      }
    }

    private string _name;
    public string name
    {
      get
      {
        if (_name == null) _name = "";
        return _name;
      }
      set
      {
        if (_name == value) return;
        _name = value;
        text_updated ();
      }
    }

    private string _description;
    public string description
    {
      get
      {
        if (_description == null) _description = "";
        return _description;
      }
      set
      {
        if (_description == value) return;
        _description = value;
        text_updated ();
      }
    }

    private string _subdesc_title;
    public string sub_description_title
    {
      get
      {
        if (_subdesc_title == null) _subdesc_title = "";
        return _subdesc_title;
      }
      set
      {
        if (_subdesc_title == value) return;
        _subdesc_title = value;
        text_updated ();
      }
    }

    private string _subdesc_text;
    public string sub_description_text
    {
      get
      {
        if (_subdesc_text == null) _subdesc_text = "";
        return _subdesc_text;
      }
      set
      {
        if (_subdesc_text == value) return;
        _subdesc_text = value;
        text_updated ();
      }
    }

    public bool show_action_button { get; set; default = true; }

    public bool enabled { get; set; default = true; }

    public string add_button_stock { get; protected set; default = Gtk.Stock.ADD; }
    public string remove_button_stock { get; protected set; default = Gtk.Stock.DELETE; }
    public string add_button_tooltip { get; protected set; }
    public string remove_button_tooltip { get; protected set; }

    public void add_user_button (Gtk.Button button)
    {
      if (extra_buttons.find (button) == null)
      {
        extra_buttons.append (button);
        buttons_updated ();
      }
    }

    public void remove_user_button (Gtk.Button button)
    {
      if (extra_buttons.find (button) != null)
      {
        extra_buttons.remove (button);
        buttons_updated ();
      }
    }
  }
}
