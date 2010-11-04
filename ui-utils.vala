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

namespace Sezen
{
  namespace Utils
  {
    private static Gdk.Pixmap transparent_pixmap = null;
    private static string home_directory = null;
    private static long home_directory_length = 0;
    
    public static string markup_string_with_search (string text, string pattern, string size = "xx-large")
    {
      if (pattern == "")
      {
        return Markup.printf_escaped ("<span size=\"%s\">%s</span>", size, text);
      }
      // if no text found, use pattern
      if (text == "")
      {
        return Markup.printf_escaped ("<span size=\"%s\">%s<b> </b></span>", size, pattern);
      }

      var matchers = Query.get_matchers_for_query (
                        Markup.escape_text (pattern), 0,
                        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
      string? highlighted = null;
      string escaped_text = Markup.escape_text (text);
      foreach (var matcher in matchers)
      {
        if (matcher.key.match (escaped_text))
        {
          try
          {
            highlighted = matcher.key.replace_eval (escaped_text, -1, 0, 0, (mi, res) =>
            {
              int start_pos;
              int end_pos;
              int last_pos = 0;
              int cnt = mi.get_match_count ();
              for (int i = 1; i < cnt; i++)
              {
                mi.fetch_pos (i, out start_pos, out end_pos);
                if (i > 1) res.append (escaped_text.substring (last_pos, start_pos - last_pos));
                last_pos = end_pos;
                res.append ("<u><b>%s</b></u>".printf (mi.fetch (i)));
              }
            });
            break;
          }
          catch (RegexError err)
          {
            warn_if_reached ();
          }
        }
      }
      if (highlighted != null)
      {
        return "<span size=\"%s\">%s</span>".printf (size,highlighted);
      }
      else
      {
        return Markup.printf_escaped ("<span size=\"%s\">%s</span>", size, text);
      }
    }
    
    public static string replace_home_path_with (string path, string replace,
                                                 string delimiter)
    {
    	if (home_directory == null)
    	{
    		home_directory = Environment.get_home_dir ();
    		home_directory_length = home_directory.length;
    	}
      if (path.has_prefix (home_directory))
      {
        string rem = path.substring (home_directory_length);
        string[] parts = Regex.split_simple ("/", rem);
        return replace + string.joinv (delimiter, parts);
      }
      else
      	return path;
    }
    
    public static void make_transparent_bg (Gtk.Widget widget)
    {
      unowned Gdk.Window window = widget.get_window ();
      if (window == null) return;
      
      if (widget.is_composited ())
      {
        if (transparent_pixmap == null)
        {
          transparent_pixmap = new Gdk.Pixmap (window, 1, 1, -1);
          var cr = Gdk.cairo_create (transparent_pixmap);
          cr.set_operator (Cairo.Operator.CLEAR);
          cr.paint ();
        }
        window.set_back_pixmap (transparent_pixmap, false);
      }
    }
    
    private static void on_style_set (Gtk.Widget widget, Gtk.Style? prev_style)
    {
      if (widget.get_realized ()) 
      {
        make_transparent_bg (widget);
        widget.queue_draw ();
      }
    }
    
    private static void on_composited_change (Gtk.Widget widget)
    {
      if (widget.is_composited ()) make_transparent_bg (widget);
      else widget.modify_bg (Gtk.StateType.NORMAL, null);
    }
    
    public static void ensure_transparent_bg (Gtk.Widget widget)
    {
      if (widget.get_realized ()) make_transparent_bg (widget);
      
      widget.realize.disconnect (make_transparent_bg);
      widget.style_set.disconnect (on_style_set);
      widget.composited_changed.disconnect (on_composited_change);
      
      widget.realize.connect (make_transparent_bg);
      widget.style_set.connect (on_style_set);
      widget.composited_changed.connect (on_composited_change);
    }

    public static void gdk_color_to_rgb (Gdk.Color col, double *r, double *g, double *b)
    {
      *r = col.red / (double)65535;
      *g = col.green / (double)65535;
      *b = col.blue / (double)65535;
    }

    public static void rgb_invert_color (out double r, out double g, out double b)
    {
      if (r >= 0.5) r /= 4; else r = 1 - r / 4;
      if (g >= 0.5) g /= 4; else g = 1 - g / 4;
      if (b >= 0.5) b /= 4; else b = 1 - b / 4;
    }
    
    private void cairo_rounded_rect (Cairo.Context ctx, double x, double y, double w, double h, double r)
    {
      double y2 = y+h, x2 = x+w;
      ctx.move_to (x, y2 - r);
      ctx.arc (x+r, y+r, r, Math.PI, Math.PI * 1.5);
      ctx.arc (x2-r, y+r, r, Math.PI * 1.5, Math.PI * 2.0);
      ctx.arc (x2-r, y2-r, r, 0, Math.PI * 0.5);
      ctx.arc (x+r, y2-r, r, Math.PI * 0.5, Math.PI);
    }
    
    private void cairo_make_shadow_for_rect (Cairo.Context ctx, double x1, double y1, double w, double h, double rad,
                                             double r, double g, double b, double a, double size)
    {
      ctx.save ();
      ctx.translate (0.5, 0.5);
      w -= 1; h -= 1;
      double x2 = x1+rad,
             x3 = x1+w-rad,
             x4 = x1+w,
             y2 = y1+rad,
             y3 = y1+h-rad,
             y4 = y1+h,
             thick = size+rad;
      double am = 0.25, amv = a * 0.25;
      /*                           y
           _____________________   1
          /                     \  2
         |                       |
         |                       | 3
          \_____________________/  4
          
      x->1 2                    3 4
      */ 
      Cairo.Pattern pat;
      /* Top left corner */
      ctx.save ();
      pat = new Cairo.Pattern.radial (x2, y2, rad, x2, y2, thick);
      pat.add_color_stop_rgba (0, r, g, b, 0);
      pat.add_color_stop_rgba (0, r, g, b, a);
      pat.add_color_stop_rgba (am, r, g, b, amv);
      pat.add_color_stop_rgba (0.9, r, g, b, 0);
      ctx.set_source (pat);
      ctx.rectangle (x1-size, y1-size, thick, thick);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      /* Bottom left corner */
      ctx.save ();
      pat = new Cairo.Pattern.radial (x2, y3, rad, x2, y3, thick);
      pat.add_color_stop_rgba (0, r, g, b, 0);
      pat.add_color_stop_rgba (0, r, g, b, a);
      pat.add_color_stop_rgba (am, r, g, b, amv);
      pat.add_color_stop_rgba (0.9, r, g, b, 0);
      ctx.set_source (pat);
      ctx.rectangle (x1-size, y3, thick, thick);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      /* Top right corner */
      ctx.save ();
      pat = new Cairo.Pattern.radial (x3, y2, rad, x3, y2, thick);
      pat.add_color_stop_rgba (0, r, g, b, 0);
      pat.add_color_stop_rgba (0, r, g, b, a);
      pat.add_color_stop_rgba (am, r, g, b, amv);
      pat.add_color_stop_rgba (0.9, r, g, b, 0);
      ctx.set_source (pat);
      ctx.rectangle (x3, y1-size, thick, thick);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      /* Bottom right corner */
      ctx.save ();
      pat = new Cairo.Pattern.radial (x3, y3, rad, x3, y3, thick);
      pat.add_color_stop_rgba (0, r, g, b, 0);
      pat.add_color_stop_rgba (0, r, g, b, a);
      pat.add_color_stop_rgba (am, r, g, b, amv);
      pat.add_color_stop_rgba (0.9, r, g, b, 0);
      ctx.set_source (pat);
      ctx.rectangle (x3, y3, thick, thick);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      /* Right */
      ctx.save ();
      pat = new Cairo.Pattern.linear (x4, 0, x4+size, 0);
      pat.add_color_stop_rgba (0, r, g, b, a);
      pat.add_color_stop_rgba (am, r, g, b, amv);
      pat.add_color_stop_rgba (0.9, r, g, b, 0);
      ctx.set_source (pat);
      ctx.rectangle (x4, y2, size, y3-y2);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      /* Left */
      ctx.save ();
      pat = new Cairo.Pattern.linear (x1, 0, x1-size, 0);
      pat.add_color_stop_rgba (0, r, g, b, a);
      pat.add_color_stop_rgba (am, r, g, b, amv);
      pat.add_color_stop_rgba (0.9, r, g, b, 0);
      ctx.set_source (pat);
      ctx.rectangle (x1-size, y2, size, y3-y2);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      /* Bottom */
      ctx.save ();
      pat = new Cairo.Pattern.linear (0, y4, 0, y4+size);
      pat.add_color_stop_rgba (0, r, g, b, a);
      pat.add_color_stop_rgba (am, r, g, b, amv);
      pat.add_color_stop_rgba (0.9, r, g, b, 0);
      ctx.set_source (pat);
      ctx.rectangle (x2, y4, x3-x2, size);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
       /* Top */
      ctx.save ();
      pat = new Cairo.Pattern.linear (0, y1, 0, y1-size);
      pat.add_color_stop_rgba (0, r, g, b, a);
      pat.add_color_stop_rgba (am, r, g, b, amv);
      pat.add_color_stop_rgba (0.9, r, g, b, 0);
      ctx.set_source (pat);
      ctx.rectangle (x2, y1-size, x3-x2, size);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      
      ctx.restore ();
    }
  }
}

