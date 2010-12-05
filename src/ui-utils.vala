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
 *						 Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

namespace Synapse.Gui
{
  namespace Utils
  {
    private static Gdk.Pixmap transparent_pixmap = null;
    private static string home_directory = null;
    private static long home_directory_length = 0;
    
    public static string markup_string_with_search (string text, string pattern, string size = "xx-large", bool show_not_found = false)
    {
    	string _size = size;
    	if (size != "")
    		_size = " size=\"%s\"".printf (size);
      if (pattern == "")
      {
        return "<span%s>%s</span>".printf (_size, Markup.escape_text(text));
      }
      // if no text found, use pattern
      if (text == "")
      {
        return "<span%s>%s</span>".printf (_size, Markup.escape_text(pattern));
      }

      var matchers = Query.get_matchers_for_query (
                        pattern, 0,
                        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
      string? highlighted = null;
      foreach (var matcher in matchers)
      {
        MatchInfo mi;
        if (matcher.key.match (text, 0, out mi))
        {
          int start_pos;
          int end_pos;
          int last_pos = 0;
          int cnt = mi.get_match_count ();
          StringBuilder res = new StringBuilder ();
          for (int i = 1; i < cnt; i++)
          {
            // fetch_pos doesn't return utf8 offsets, so we can't use 
            // string.substring ()
            mi.fetch_pos (i, out start_pos, out end_pos);
            warn_if_fail (start_pos >= 0 && end_pos >= 0);
            char* str_ptr = text;
            str_ptr += last_pos;
            unowned string non_matched = (string) str_ptr;
            res.append (Markup.escape_text (non_matched.ndup (start_pos - last_pos)));
            last_pos = end_pos;
            res.append (Markup.printf_escaped ("<u><b>%s</b></u>", mi.fetch (i)));
            if (i == cnt - 1)
            {
              str_ptr = text;
              str_ptr += last_pos;
              non_matched = (string) str_ptr;
              res.append (Markup.escape_text (non_matched));
            }
          }
          highlighted = res.str;
          break;
        }
      }
      if (highlighted != null)
      {
        return "<span%s>%s</span>".printf (_size, highlighted);
      }
      else
      {
      	if (show_not_found)
      		return "<span%s>%s <small><small>(%s)</small></small></span>".printf (_size, Markup.escape_text(text), Markup.escape_text(pattern));
       	else
       		return "<span%s>%s</span>".printf (_size, Markup.escape_text(text));
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
    
    private static Gdk.Rectangle get_current_monitor_geometry (Gdk.Screen screen) 
    {
    	var display = screen.get_display ();
    	int x = 0, y = 0;
    	Gdk.Screen screen_for_pointer = null;
    	display.get_pointer (out screen_for_pointer, out x, out y, null);
    	
    	Gdk.Rectangle rect = {0, 0};
    	screen_for_pointer.get_monitor_geometry (screen_for_pointer.get_monitor_at_point (x, y), out rect);
    	
    	return rect;
    }
    public static void move_window_to_center (Gtk.Window win)
    {
      Gdk.Screen screen = win.get_screen () ?? Gdk.Screen.get_default ();
      if (screen == null)
      	return;
      var rect = get_current_monitor_geometry (screen);
      Gtk.Requisition req = {0, 0};
      win.size_request (out req);
      win.move (rect.x + (rect.width - req.width) / 2, rect.y + (rect.height - req.height) / 2);
    }

    public static void gdk_color_to_rgb (Gdk.Color col, out double r, out double g, out double b)
    {
      r = col.red / (double)65535;
      g = col.green / (double)65535;
      b = col.blue / (double)65535;
    }

    public static void rgb_invert_color (ref double r, ref double g, ref double b)
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
    public class ColorHelper 
    {
      public enum StyleType
      {
        BG,
        FG,
        BASE,
        TEXT
      }
      public enum Mod
      {
        NORMAL,
        LIGHTER,
        DARKER,
        INVERTED
      }
      private static ColorHelper helper = null;
      public static unowned ColorHelper get_default ()
      {
        if (helper == null)
          helper = new ColorHelper ();
        return helper;
      }
      private class Color
      {
        public double r;
        public double g;
        public double b;
        public Color ()
        {
          this.r = 0;
          this.g = 0;
          this.b = 0;
        }
        public void init_from_gdk_color (Gdk.Color col)
        {
          gdk_color_to_rgb (col, out this.r, out this.g, out this.b);
        }

        public void init_from_rgb (double r, double g, double b)
        {
          this.r = r;
          this.g = g;
          this.b = b;
        }

        public void clone (Color col)
        {
          this.r = col.r;
          this.g = col.g;
          this.b = col.b;
        }
        
        public void apply_mod (Mod k)
        {
          switch (k)
          {
            case Mod.INVERTED:
              Utils.rgb_invert_color (ref this.r, ref this.g, ref this.b);
              break;
            case Mod.LIGHTER:
            	murrine_shade (ref this.r, ref this.g, ref this.b, 1.10);
            	break;
           	case Mod.DARKER:
           		murrine_shade (ref this.r, ref this.g, ref this.b, 0.90);
           		break;
            default:
              break;
          }
        }
        /* RGB / HLS utils - from Murrine gtk-engine:
         * Copyright (C) 2006-2007-2008-2009 Andrea Cimitan
         */
        private static void murrine_rgb_to_hls (double *r,
								                                double *g,
								                                double *b)
        {
	        double min;
	        double max;
	        double red;
	        double green;
	        double blue;
	        double h = 0, l = 0, s = 0;
	        double delta;

	        red = *r;
	        green = *g;
	        blue = *b;

	        if (red > green)
	        {
		        if (red > blue)
			        max = red;
		        else
			        max = blue;

		        if (green < blue)
			        min = green;
		        else
			        min = blue;
	        }
	        else
	        {
		        if (green > blue)
			        max = green;
		        else
			        max = blue;

		        if (red < blue)
			        min = red;
		        else
			        min = blue;
	        }

	        l = (max+min)/2;
	        if (Math.fabs (max-min) < 0.0001)
	        {
		        h = 0;
		        s = 0;
	        }
	        else
	        {
		        if (l <= 0.5)
			        s = (max-min)/(max+min);
		        else
			        s = (max-min)/(2-max-min);

		        delta = max -min;
		        if (red == max)
			        h = (green-blue)/delta;
		        else if (green == max)
			        h = 2+(blue-red)/delta;
		        else if (blue == max)
			        h = 4+(red-green)/delta;

		        h *= 60;
		        if (h < 0.0)
			        h += 360;
	        }

	        *r = h;
	        *g = l;
	        *b = s;
        }

        private static void murrine_hls_to_rgb (double *h,
								                                double *l,
								                                double *s)
        {
	        double hue;
	        double lightness;
	        double saturation;
	        double m1, m2;
	        double r = 0, g = 0, b = 0;

	        lightness = *l;
	        saturation = *s;

	        if (lightness <= 0.5)
		        m2 = lightness*(1+saturation);
	        else
		        m2 = lightness+saturation-lightness*saturation;

	        m1 = 2*lightness-m2;

	        if (saturation == 0)
	        {
		        *h = lightness;
		        *l = lightness;
		        *s = lightness;
	        }
	        else
	        {
		        hue = *h+120;
		        while (hue > 360)
			        hue -= 360;
		        while (hue < 0)
			        hue += 360;

		        if (hue < 60)
			        r = m1+(m2-m1)*hue/60;
		        else if (hue < 180)
			        r = m2;
		        else if (hue < 240)
			        r = m1+(m2-m1)*(240-hue)/60;
		        else
			        r = m1;

		        hue = *h;
		        while (hue > 360)
			        hue -= 360;
		        while (hue < 0)
			        hue += 360;

		        if (hue < 60)
			        g = m1+(m2-m1)*hue/60;
		        else if (hue < 180)
			        g = m2;
		        else if (hue < 240)
			        g = m1+(m2-m1)*(240-hue)/60;
		        else
			        g = m1;

		        hue = *h-120;
		        while (hue > 360)
			        hue -= 360;
		        while (hue < 0)
			        hue += 360;

		        if (hue < 60)
			        b = m1+(m2-m1)*hue/60;
		        else if (hue < 180)
			        b = m2;
		        else if (hue < 240)
			        b = m1+(m2-m1)*(240-hue)/60;
		        else
			        b = m1;

		        *h = r;
		        *l = g;
		        *s = b;
	        }
        }

        private static void murrine_shade (ref double r, ref double g, ref double b, double k)
        {
	        double red;
	        double green;
	        double blue;

	        red   = r;
	        green = g;
	        blue  = b;

	        if (k == 1.0)
	        {
		        r = red;
		        g = green;
		        b = blue;
		        return;
	        }

	        murrine_rgb_to_hls (&red, &green, &blue);

	        green *= k;
	        if (green > 1.0)
		        green = 1.0;
	        else if (green < 0.0)
		        green = 0.0;

	        blue *= k;
	        if (blue > 1.0)
		        blue = 1.0;
	        else if (blue < 0.0)
		        blue = 0.0;

	        murrine_hls_to_rgb (&red, &green, &blue);

	        r = red;
	        g = green;
	        b = blue;
        }
      }
      /* [StyleType, StateType, Mod] */
      private Color[,,] c;
      /* End of static section */
      private ColorHelper ()
      {
        c = new Color[4,5,4];
        for (int i = 0; i < 4; i++)
          for (int j = 0; j < 5; j++)
            for (int k = 0; k < 4; k++)
              c[i,j,k] = new Color ();
      }
      protected Gtk.Style current_style = null;
      public void force_color_helper_style_on_widget (Gtk.Widget w)
      {
      	if (current_style != null)
	      	w.style = current_style;
      	//w.style_set.disconnect (_style_set_cb);
      	//w.style_set.connect (_style_set_cb);
      }
      private void _style_set_cb (Gtk.Widget widget, Gtk.Style? prev_style)
      {
      	if (current_style != null)
    			widget.set_style (current_style);
      }
      public void init_from_widget_type (Type widget_type)
      {
        Gtk.Widget widget = (Gtk.Widget) Object.new (widget_type);
      	current_style = Gtk.rc_get_style (widget);
      	_init_from_style (current_style);
      }
      
      public void init_from_panel_or_widget_type (Type widget_type)
      {
        Gtk.Settings sett = Gtk.Settings.get_default ();
        current_style = Gtk.rc_get_style_by_paths (sett, "PanelWidget", "", 0);
        if (current_style == null)
        	init_from_widget_type (widget_type);
        else
        	_init_from_style (current_style);
      }
      
      public void _init_from_style (Gtk.Style s)
      {
        for (int j = 0; j < 5; j++)
        {
          c[StyleType.BG,j,0].init_from_gdk_color (s.bg[j]);
          for (int k = 1; k < 4; k++)
          {
            c[StyleType.BG,j,k].clone (c[StyleType.BG,j,0]);
            c[StyleType.BG,j,k].apply_mod ((Mod)k);
          }
        }
        for (int j = 0; j < 5; j++)
        {
          c[StyleType.FG,j,0].init_from_gdk_color (s.fg[j]);
          for (int k = 1; k < 4; k++)
          {
            c[StyleType.FG,j,k].clone (c[StyleType.FG,j,0]);
            c[StyleType.FG,j,k].apply_mod ((Mod)k);
          }
        }
        for (int j = 0; j < 5; j++)
        {
          c[StyleType.TEXT,j,0].init_from_gdk_color (s.text[j]);
          for (int k = 1; k < 4; k++)
          {
            c[StyleType.TEXT,j,k].clone (c[StyleType.TEXT,j,0]);
            c[StyleType.TEXT,j,k].apply_mod ((Mod)k);
          }
        }
        for (int j = 0; j < 5; j++)
        {
          c[StyleType.BASE,j,0].init_from_gdk_color (s.base[j]);
          for (int k = 1; k < 4; k++)
          {
            c[StyleType.BASE,j,k].clone (c[StyleType.BASE,j,0]);
            c[StyleType.BASE,j,k].apply_mod ((Mod)k);
          }
        }
      }
      public void set_source_rgba (Cairo.Context ctx, double alpha, StyleType t, Gtk.StateType st, Mod mod = Mod.NORMAL)
      {
        Color col = c[t,st,mod];
        ctx.set_source_rgba (col.r, col.g, col.b, alpha);
      }
      public void add_color_stop_rgba (Cairo.Pattern pat, double val, double alpha, StyleType t, Gtk.StateType st, Mod mod = Mod.NORMAL)
      {
        Color col = c[t,st,mod];
        pat.add_color_stop_rgba (val, col.r, col.g, col.b, alpha);
      }
      public void get_rgb (out double r, out double g, out double b, StyleType t, Gtk.StateType st, Mod mod = Mod.NORMAL)
      {
        Color col = c[t,st,mod];
        r = col.r;
        g = col.g;
        b = col.b;
      }
    }
  }
}

