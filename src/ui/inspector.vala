/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
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
 *
 */

using Gtk;

namespace UI
{
  public class Inspector
  {
    private uint timer_id = 0;

    public Inspector ()
    {
      timer_id = Timeout.add (500, this.check_window_at_pointer);
    }
  
    ~Inspector ()
    {
      Source.remove (timer_id);
    }
    
    private unowned Widget? find_child (Container container, int widget_x, int widget_y)
    {
      foreach (unowned Widget child in container.get_children ())
      {
        Allocation alloc;
        child.get_allocation (out alloc);
        if (widget_x >= alloc.x && widget_x < alloc.x + alloc.width &&
            widget_y >= alloc.y && widget_y < alloc.y + alloc.height)
        {
          if (child is Container)
          {
            return find_child (child as Container, widget_x, widget_y);
          }
          return child;
        }
      }
      
      return container;
    }
    
    private unowned Widget last_exposed = null;
    private unowned Widget last_exposed_container = null;
  
    private bool check_window_at_pointer ()
    {
      int win_x, win_y;
      Gdk.Window? window = Gdk.Window.at_pointer (out win_x, out win_y);
      if (window != null)
      {
        unowned Widget widget = null;
        
        window.get_user_data (&widget);
        if (widget is Container)
        {
          widget = find_child (widget as Container, win_x, win_y);
        }

        if (last_exposed != null)
        {
          last_exposed.expose_event.disconnect (this.paint_border);
          last_exposed.queue_draw ();
        }
        if (last_exposed_container != null)
        {
          last_exposed_container.expose_event.disconnect (this.paint_border);
          last_exposed_container.queue_draw ();
        }
        last_exposed = widget;
        last_exposed_container = widget.get_parent ();
        widget.expose_event.connect_after (this.paint_border);
        widget.queue_draw ();
        last_exposed_container.expose_event.connect_after (this.paint_border);
        last_exposed_container.queue_draw ();
      }
      return true;
    }
    
    private bool paint_border (Widget widget, Gdk.EventExpose event)
    {
      var cr = Gdk.cairo_create (event.window);
      cr.set_operator (Cairo.Operator.OVER);
      cr.set_line_width (1.0);
      if (widget == last_exposed_container)
      {
        double[] dashes = {2.0};
        cr.set_dash (dashes, 0.0);
        cr.set_source_rgb (0.0, 0.0, 1.0);
      }
      else
      {
        cr.set_source_rgb (1.0, 0.0, 0.0);
      }
      cr.translate (0.5, 0.5);
      cr.rectangle (widget.allocation.x, widget.allocation.y,
                    widget.allocation.width-1, widget.allocation.height-1);
      cr.stroke ();
      
      Cairo.TextExtents ext;
      unowned string widget_name = widget.get_type ().name ();
      cr.text_extents (widget_name, out ext);
      if (widget.allocation.width >= ext.width && widget.allocation.height >= ext.height)
      {
        cr.move_to (widget.allocation.x + widget.allocation.width - ext.width - 1,
                    widget.allocation.y + ext.height);
        cr.show_text (widget_name);
      }
      return false;
    }
  }
}

