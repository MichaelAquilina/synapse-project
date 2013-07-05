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
  public class WrapLabel: Label
  {
    private float orig_yalign = 0.5f;
    private bool _wrap = false;
    public new bool wrap { 
      get
      {
        return _wrap;
      }
      construct set
      {
        _wrap = value;
        this.max_width_chars = _wrap ? -1 : 10;
        this.set_ellipsize (_wrap ? Pango.EllipsizeMode.NONE : 
                                    Pango.EllipsizeMode.END);
        if (!_wrap) orig_yalign = this.yalign;
        this.yalign = _wrap ? 0.0f : orig_yalign;
        this.queue_resize ();
      }
    }
    public WrapLabel ()
    {
      GLib.Object (xalign: 0.0f, wrap: false);
    }

    construct
    {
    }

    protected override void size_allocate (Gtk.Allocation allocation)
    {
      var layout = this.get_layout ();
      layout.set_width (allocation.width * Pango.SCALE);

      int lw, lh;
      layout.get_pixel_size (out lw, out lh);

      this.height_request = lh;

      base.size_allocate (allocation);
    }

    protected override void get_preferred_width (out int min_width, out int nat_width)
    {
      base.get_preferred_width (out min_width, out nat_width);
      min_width = nat_width = 30;
      if (_wrap) {
        min_width = nat_width = 1;
      }
    }
  }
}
