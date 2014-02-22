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

using Gtk;
using Cairo;
using Gee;

namespace Synapse.Gui
{
  public errordomain WidgetError
  {
    ICON_NOT_FOUND,
    UNKNOWN
  }
  
  public class UIWidgetsConfig : ConfigObject
  {
    public bool animation_enabled { get; set; default = true; }
    public bool extended_info_enabled { get; set; default = true; }
  }
  
  public class CloneWidget : Gtk.Widget
  {
    private Widget clone;
    public CloneWidget (Widget to_clone)
    {
      this.clone = to_clone;
      this.set_has_window (false);
    }
    public override void get_preferred_width (out int min_width, out int nat_width)
    {
      clone.get_preferred_width (out min_width, out nat_width);
    }
    public override void get_preferred_height (out int min_height, out int nat_height)
    {
      clone.get_preferred_height (out min_height, out nat_height);
    }
  }

  public class SmartLabel : Gtk.Misc
  {
    public static const string[] size_to_string = {
      "xx-small",
      "x-small",
      "small",
      "medium",
      "large",
      "x-large",
      "xx-large"
    };
    
    public static Size string_to_size (string sizename)
    {
      Size s = Size.MEDIUM;
      for (uint i = 0; i < size_to_string.length; i++)
      {
        if (size_to_string[i] == sizename) return (Size)i;
      }
      return s;
    }
    
    protected static const double[] size_to_scale = {
      Pango.Scale.XX_SMALL,
      Pango.Scale.X_SMALL,
      Pango.Scale.SMALL,
      Pango.Scale.MEDIUM,
      Pango.Scale.LARGE,
      Pango.Scale.X_LARGE,
      Pango.Scale.XX_LARGE
    };

    public enum Size
    {
      XX_SMALL,
      X_SMALL,
      SMALL,
      MEDIUM,
      LARGE,
      X_LARGE,
      XX_LARGE
    }
    
    public bool natural_requisition {
      get; set; default = false;
    }
    
    public Size size {
      get; set; default = Size.MEDIUM;
    }

    public Size min_size {
      get; set; default = Size.MEDIUM;
    }
    
    private string text = "";
    
    private Size real_size = Size.MEDIUM;
    private Requisition last_req;
    private Pango.Layout layout;
    private Utils.ColorHelper ch;
    private Pango.EllipsizeMode ellipsize = Pango.EllipsizeMode.NONE;
    
    private uint tid = 0;
    private static const int INITIAL_TIMEOUT = 1750;
    private static const int SPACING = 50;
    private int offset = 0;
    private bool animate = false;

    construct
    {
      layout = this.create_pango_layout ("");
      ch = Utils.ColorHelper.get_default ();
      last_req = {0, 0};
      this.set_has_window (false);
      this.notify["size"].connect (sizes_changed);
      this.notify["min-size"].connect (sizes_changed);
      this.xalign = 0.0f;
      this.yalign = 1.0f;

      //do not remove this, it's important to create the first scale attr
      this.set_text ("");
    }

    private void sizes_changed ()
    {
      if (min_size > size) this._min_size = this._size;
      this.real_size = size;
      queue_resize ();
    }
    
    public void set_animation_enabled (bool b)
    {
      this.animate = b;

      if (b)
      {
        this.ellipsize = Pango.EllipsizeMode.NONE;
        sizes_changed ();
      }
      else
      {
        if (tid != 0) stop_animation ();
        sizes_changed ();
      }
    }
    
    public void set_text (string s)
    {
      string m = Markup.escape_text (s);
      if (m == text) return;
      text = m;
      text_updated ();
    }
    
    public void set_markup (string m)
    {
      if (m == text) return;
      text = m;
      text_updated ();
    }
    
    private void stop_animation ()
    {
      Source.remove (tid);
      tid = 0;
      offset = 0;
    }
    
    int _anim_width = 0;
    private void start_animation ()
    {
      if (tid != 0) return;

      tid = Timeout.add (40, ()=>{
        offset = (offset - 1) % (_anim_width);
        queue_draw ();
        return true;
      });
    }
    
    public void set_ellipsize (Pango.EllipsizeMode mode)
    {
      if (animate) this.ellipsize = Pango.EllipsizeMode.NONE;
      else this.ellipsize = mode;
    }
    
    private void text_updated ()
    {
      real_size = _size;
      queue_resize ();
      if (tid != 0) stop_animation ();
    }
    
    public override void size_allocate (Gtk.Allocation allocation)
    {
      base.size_allocate (allocation);

      /* size_allocate is called after size_request */
      /* so last_req is filled with the standard requisition */

      if (allocation.width >= last_req.width || ((!animate) && real_size == _min_size))
      {
        /* That's good, we have enough space for default size */
        if (tid != 0) stop_animation ();
        return;
      }
      /* Mh, bad, let's start shrinking */
      Requisition req;

      var attrs = layout.get_attributes ();
      var iter = attrs.get_iterator (); //the first iterator is a scale
      unowned Pango.Attribute? attr = iter.get (Pango.AttrType.SCALE);
      unowned Pango.AttrFloat a = (Pango.AttrFloat) attr;

      bool needs_animation = true;
      while (real_size > _min_size)
      {
        real_size = real_size - 1;
        a.value = size_to_scale[real_size];
        layout.context_changed ();
        requisition_for_size (out req, null, real_size, true);

        if (allocation.width >= req.width)
        {
          needs_animation = false;
          break;
        }
      }

      if (animate && needs_animation)
      {
        if (tid == 0)
        {
          tid = Timeout.add (INITIAL_TIMEOUT, ()=>{
            tid = 0;
            start_animation ();
            return false;
          });
        }
      }
      else
      {
        if (tid != 0) stop_animation ();
      }
    }
    
    public override bool draw (Cairo.Context ctx)
    {
      int w = this.get_allocated_width () - this.xpad * 2;
      int h = this.get_allocated_height () - this.ypad * 2;
      ctx.translate (this.xpad, this.ypad);
      ctx.rectangle (0, 0, w, h);
      ctx.clip ();
      
      bool rtl = this.get_direction () == Gtk.TextDirection.RTL;

      int x, y, width, height;
      
      if (animate && tid != 0)
      {
        ctx.translate (offset, 0);
      }
      else
      {
        if (ellipsize != Pango.EllipsizeMode.NONE)
        {
          layout.set_width (w * Pango.SCALE);
          layout.set_ellipsize (ellipsize);
        }
      }
      
      Gui.Utils.get_draw_position (out x, out y, out width, out height, layout, rtl,
                                   w, h, this.xalign, this.yalign);
      ctx.translate (x, y);
      
      ctx.set_operator (Cairo.Operator.OVER);
      ch.set_source_rgba (ctx, 1.0, StyleType.FG, this.get_state_flags ());
      
      Pango.cairo_show_layout (ctx, layout);
      
      width += SPACING;
      _anim_width = width;
      int rotate = (offset + width);
      if (rtl) rotate = offset;
      if (animate && tid != 0 && rotate < w)
      {
        ctx.translate (width, 0);
        Pango.cairo_show_layout (ctx, layout);
      }

      return true;
    }

    protected void requisition_for_size (out Requisition req, out int char_width, Size s, bool return_only_width = false)
    {
      req = { this.xpad * 2, this.ypad * 2 };

      Pango.Rectangle logical_rect;
      layout.set_width (-1);
      layout.set_ellipsize (Pango.EllipsizeMode.NONE);
      layout.get_extents (null, out logical_rect);
      
      req.width += logical_rect.width / Pango.SCALE;
      if (return_only_width)
      {
        char_width = 0;
        return;
      }
      
      Pango.Context ctx = layout.get_context ();
      Pango.FontDescription fdesc = new Pango.FontDescription ();
      fdesc.merge_static (this.style.font_desc, true);

      fdesc.set_size ((int)(size_to_scale[s] * (double)fdesc.get_size()));
      var metrics = ctx.get_metrics (fdesc, ctx.get_language ());

      req.height += (metrics.get_ascent () + metrics.get_descent ()) / Pango.SCALE;
      char_width = int.max (metrics.get_approximate_char_width (), metrics.get_approximate_digit_width ()) / Pango.SCALE;
    }
    
    public void size_request (out Requisition req)
    {
      layout.set_markup ("<span size=\"%s\">%s</span>".printf (size_to_string[_size], this.text), -1);
      int char_width;
      this.requisition_for_size (out req, out char_width, this._size);
      last_req.width = req.width;
      last_req.height = req.height;
      if (!this.natural_requisition && (this.ellipsize != Pango.EllipsizeMode.NONE || animate))
        req.width = char_width * 3;
    }

    public override void get_preferred_width (out int min_width, out int nat_width)
    {
      Requisition req;
      this.size_request (out req);
      min_width = nat_width = req.width;
    }

    public override void get_preferred_height (out int min_height, out int nat_height)
    {
      Requisition req;
      this.size_request (out req);
      min_height = nat_height = req.height;
    }
  }
  
  public class SchemaContainer: Gtk.Container
  {
    public class Schema : GLib.Object
    {
      private Allocation[] _positions = {};
      public Allocation[] positions { get {return _positions;} }
      public Schema ()
      {

      }
      public void add_allocation (Allocation alloc)
      {
        alloc.x = int.max (0, alloc.x);
        alloc.y = int.max (0, alloc.y);
        alloc.width = int.max (0, alloc.width);
        alloc.height = int.max (0, alloc.height);

        this._positions += alloc;
      }
    }
    
    protected Gee.List<Schema> schemas;
    protected Gee.List<Widget> children;
    private int active_schema = 0;
    private int[] render_order = null;
    
    public int xpad { get; set; default = 0; }
    public int ypad { get; set; default = 0; }
    
    public int scale_size {
      get; set; default = 128;
    }
    
    public bool fixed_height {
      get; set; default = false;
    }
    
    public bool fixed_width {
      get; set; default = false;
    }
    
    public SchemaContainer (int scale_size)
    {
      this.scale_size = scale_size;
      schemas = new Gee.ArrayList<Schema> ();
      children = new Gee.ArrayList<Widget> ();
      set_has_window (false);
      set_redraw_on_allocate (false);
      this.notify["scale-size"].connect (this.queue_resize);
      this.notify["fixed-width"].connect (this.queue_resize);
      this.notify["fixed-height"].connect (this.queue_resize);
      this.notify["xpad"].connect (this.queue_resize);
      this.notify["ypad"].connect (this.queue_resize);
    }
    
    public void set_render_order (int[]? order)
    {
      this.render_order = order;
      this.queue_draw ();
    }

    public new void set_size_request (int width, int height)
    {
      if (width <= 0) width = 1;
      if (height <= 0) height = 1;
      
      base.set_size_request (width, height);
    }
    
    public void add_schema (Schema s)
    {
      schemas.add (s);
      if (schemas.size == 1) select_schema (0);
    }
    
    public void select_schema (int i)
    {
      if (i < 0) return;
      if (i >= schemas.size) return;
      active_schema = i;
      if (!this.get_realized ()) return;
      Gtk.Allocation alloc;
      this.get_allocation (out alloc);
      size_allocate ({
        alloc.x, alloc.y,
        alloc.width, alloc.height
      });
      queue_resize ();
    }
    
    
    
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      if (render_order == null)
      {
        foreach (var child in children)
        {
          callback (child);
        }
      }
      else
      {
        for (int i = 0; i < render_order.length; i++)
          callback (children.get (render_order[i]));
      }
    }
    
    public override void add (Widget widget)
    {
      this.children.add (widget);
      widget.set_parent (this);
    }
    
    public override void remove (Widget widget)
    {
      // cannot remove for now :P TODO
    }
    
    public void size_request (out Gtk.Requisition req)
    {
      req = {0, 0};
      int i = 0;
      Allocation[] alloc = schemas.get (active_schema).positions;

      foreach (Widget child in children)
      {
        if (alloc.length > i)
        {
          req.width = int.max ((alloc[i].x+alloc[i].width)*_scale_size/100, req.width);
          req.height = int.max ((alloc[i].y+alloc[i].height)*_scale_size/100, req.height);
          child.visible = true;
        }
        else
        {
          child.visible = false;
        }
        i++;
      }
      if (this._fixed_height) req.height = this._scale_size;
      if (this._fixed_width) req.width = this._scale_size;
      req.width += _xpad * 2;
      req.height += _ypad * 2;
    }
    
    public override void get_preferred_width (out int min_width, out int nat_width)
    {
      Requisition req;
      this.size_request (out req);
      min_width = nat_width = req.width;
    }

    public override void get_preferred_height (out int min_height, out int nat_height)
    {
      Requisition req;
      this.size_request (out req);
      min_height = nat_height = req.height;
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
      base.size_allocate (allocation);
      
      if (schemas.size <= 0)
      {
        foreach (Widget child in children)
          child.hide ();
        return;
      }
      Allocation[] alloc = schemas.get (active_schema).positions;
      
      int i = 0;
      int x = allocation.x + _xpad;
      int y = allocation.y + _ypad;
      bool rtl = this.get_direction () == Gtk.TextDirection.RTL;
      foreach (Widget child in children)
      {
        Gtk.Allocation a;
        if (alloc.length <= i)
        {
          a = {
            0, 0, 0, 0
          };
        }
        else
        {
          a = {
            x + alloc[i].x * this._scale_size / 100,
            y + alloc[i].y * this._scale_size / 100,
            alloc[i].width * this._scale_size / 100,
            alloc[i].height * this._scale_size / 100
          };
        }
        if (rtl) a.x = 2 * allocation.x + allocation.width - a.x - a.width;
        child.size_allocate (a);
        i++;
      }
    }
  }
  
  public class SelectionContainer: Gtk.Container
  {
    protected Gee.List<Widget> children;
    private int active_child = 0;
    
    public SelectionContainer ()
    {
      children = new Gee.ArrayList<Widget> ();
      set_has_window (false);
      set_redraw_on_allocate (false);
    }
    
    public void select_child (int i)
    {
      if (i < 0) return;
      if (i >= children.size) return;
      active_child = i;
      i = 0;
      foreach (var child in children)
      {
        if (i == active_child)
        {
          if (!child.visible) child.show ();
        }
        else
        {
          if (child.visible) child.hide ();
        }
        
        i++;
      }
      if (!this.get_realized ()) return;
      queue_resize ();
    }
    
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      foreach (var child in children)
        callback (child);
    }
    
    public override void add (Widget widget)
    {
      this.children.add (widget);
      widget.set_parent (this);
    }
    
    public override void remove (Widget widget)
    {
      this.children.remove (widget);
      widget.unparent ();
    }
    
    public override void size_allocate (Gtk.Allocation allocation)
    {
      base.size_allocate (allocation);
      if (active_child >= children.size) return;
      children.get (active_child).size_allocate (allocation);
    }
    
    public override void get_preferred_width (out int min_width, out int nat_width)
    {
      if (active_child >= children.size) {
        min_width = nat_width = 0;
        return;
      }
      children.get (active_child).get_preferred_width (out min_width, out nat_width);
    }

    public override void get_preferred_height (out int min_height, out int nat_height)
    {
      if (active_child >= children.size) {
        min_height = nat_height = 0;
        return;
      }
      children.get (active_child).get_preferred_height (out min_height, out nat_height);
    }
  }

  public class Throbber: Spinner
  {
    construct
    {
      this.notify["active"].connect (this.queue_draw);
    }

    public override bool draw (Cairo.Context ctx)
    {
      if (this.active)
      {
        return base.draw (ctx);
      }
      return true;
    }
  }
  
  public class SensitiveWidget: Gtk.EventBox
  {
    private Widget _widget;
    public Widget widget {get {return this._widget;}}

    public SensitiveWidget (Widget widget)
    {
      this.above_child = false;
      this.visible_window = false;
      this.set_has_window (false);
      
      this._widget = widget;
      this.add (this._widget);
      this._widget.show ();
    }
    
    public override bool draw (Cairo.Context ctx)
    {
      this.propagate_draw (this.get_child (), ctx);
      return true;
    }
  }

  public class NamedIcon: Gtk.Image
  {
    public string not_found_name {get; set; default = "unknown";}
    private string current;
    private IconSize current_size;
    
    construct
    {
      current = "";
      current_size = IconSize.DIALOG;
    }
    
    public void size_request (out Requisition req)
    {
      req = {
        this.width_request,
        this.height_request
      };
      if (req.width <= 0 && req.height <= 0)
      {
        req.width = xpad * 2;
        req.height = ypad * 2;
        if (pixel_size >= 0)
        {
          req.width += pixel_size;
          req.height += pixel_size;
        }
      }
    }

    public override void get_preferred_width (out int min_width, out int nat_width)
    {
      Requisition req;
      this.size_request (out req);
      min_width = nat_width = req.width;
    }

    public override void get_preferred_height (out int min_height, out int nat_height)
    {
      Requisition req;
      this.size_request (out req);
      min_height = nat_height = req.height;
    }

    public override bool draw (Cairo.Context ctx)
    {
      if (current == null || current == "") return true;
      ctx.set_operator (Cairo.Operator.OVER);

      Gtk.Allocation allocation;
      this.get_allocation (out allocation);

      int w = this.get_allocated_width () - this.xpad * 2;
      int h = this.get_allocated_height () - this.ypad * 2;
      ctx.translate (this.xpad, this.ypad);
      ctx.rectangle (0, 0, w, h);
      ctx.clip ();

      Gdk.Pixbuf icon_pixbuf = IconCacheService.get_default ().get_icon (
            current, pixel_size <= 0 ? int.min (this.get_allocated_width (), this.get_allocated_height ()) : pixel_size);

      if (icon_pixbuf == null) return true;

      Gdk.cairo_set_source_pixbuf (ctx, icon_pixbuf, 
          (w - icon_pixbuf.get_width ()) / 2, 
          (h - icon_pixbuf.get_height ()) / 2);
      ctx.paint ();

      return true;
    }
    public new void clear ()
    {
      current = "";
      this.queue_draw ();
    }
    public void set_icon_name (string? name, IconSize size = IconSize.DND)
    {
      if (name == null)
        name = "";
      if (name == current && name != "")
        return;
      else
      {
        if (name == "")
        {
          name = not_found_name;
        }
        current = name;
        current_size = size;
        this.queue_draw ();
      }
    }
  }

  public class FakeInput: Gtk.Alignment
  {
    public bool draw_input {get; set; default = true;}
    public double input_alpha {get; set; default = 1.0;}
    public double border_radius {get; set; default = 3.0;}
    public double shadow_height {get; set; default = 3;}
    public double focus_height {get; set; default = 3;}
    
    private Utils.ColorHelper ch;
    public Widget? focus_widget 
    {
      get {return _focus_widget;}
      set {
        if (value == _focus_widget)
          return;
        this.queue_draw ();
        if (_focus_widget != null)
          _focus_widget.queue_draw ();
        _focus_widget = value;
        if (_focus_widget != null)
          _focus_widget.queue_draw ();
      }
    }
    private Widget? _focus_widget;
    construct
    {
      _focus_widget = null;
      ch = Utils.ColorHelper.get_default ();
      this.notify["draw-input"].connect (this.queue_draw);
      this.notify["input-alpha"].connect (this.queue_draw);
      this.notify["border-radius"].connect (this.queue_draw);
      this.notify["shadow-pct"].connect (this.queue_draw);
      this.notify["focus-height"].connect (this.queue_draw);
    }

    public override bool draw (Cairo.Context ctx)
    {
      if (draw_input)
      {
        ctx.save ();
        ctx.translate (1.5, 1.5);
        ctx.set_operator (Cairo.Operator.OVER);
        ctx.set_line_width (1.25);

        Gdk.cairo_rectangle (ctx, {0, 0, this.get_allocated_width (), this.get_allocated_height ()});
        ctx.clip ();
        ctx.save ();

        double x = this.left_padding,
               y = this.top_padding,
               w = this.get_allocated_width () - this.left_padding - this.right_padding - 3.0,
               h = this.get_allocated_height () - this.top_padding - this.bottom_padding - 3.0;
        Utils.cairo_rounded_rect (ctx, x, y, w, h, border_radius);
        if (!ch.is_dark_color (StyleType.FG, StateFlags.NORMAL))
          ch.set_source_rgba (ctx, input_alpha, StyleType.BG, StateFlags.NORMAL, Mod.DARKER);
        else
          ch.set_source_rgba (ctx, input_alpha, StyleType.FG, StateFlags.NORMAL, Mod.INVERTED);
        ctx.fill_preserve ();
        var pat = new Cairo.Pattern.linear (0, y, 0, y + shadow_height);
        ch.add_color_stop_rgba (pat, 0, 0.6 * input_alpha, StyleType.FG, StateFlags.NORMAL);
        ch.add_color_stop_rgba (pat, 0.3, 0.25 * input_alpha, StyleType.FG, StateFlags.NORMAL);
        ch.add_color_stop_rgba (pat, 1.0, 0, StyleType.FG, StateFlags.NORMAL);
        ctx.set_source (pat);
        ctx.fill ();
        if (_focus_widget != null)
        {
          /*
                     ____            y1
                  .-'    '-.
               .-'          '-.
            .-'                '-.
           x1         x2         x3  y2
          */
          Gtk.Allocation focus_allocation;
          _focus_widget.get_allocation (out focus_allocation);
          double x1 = double.max (focus_allocation.x, x),
                 x3 = double.min (focus_allocation.x + focus_allocation.width,
                           x + w);
          double x2 = (x1 + x3) / 2.0;
          double y2 = y + h;
          double y1 = y + h - focus_height;
          ctx.new_path ();
          ctx.move_to (x1, y2);
          if (x1 < x + 1)
          {
            ctx.line_to (x1, y1);
            ctx.line_to (x2, y1);
          }
          else
          {
            ctx.curve_to (x1, y2, x1, y1, x2, y1);
          }
          if (x3 > x + w - 1)
          {
            ctx.line_to (x3, y1);
            ctx.line_to (x3, y2);
          }
          else
          {
            ctx.curve_to (x3, y1, x3, y2, x3, y2);
          }
          ctx.close_path ();
          ctx.clip ();
          pat = new Cairo.Pattern.linear (0, y2, 0, y1);
          ch.add_color_stop_rgba (pat, 0, 1.0 * input_alpha, StyleType.BG, StateFlags.SELECTED);
          ch.add_color_stop_rgba (pat, 1, 0, StyleType.BG, StateFlags.SELECTED);
          ctx.set_source (pat);
          ctx.paint ();
        }
        ctx.restore ();
        Utils.cairo_rounded_rect (ctx, x, y, w, h, border_radius);
        ch.set_source_rgba (ctx, 0.6 * input_alpha, StyleType.FG, StateFlags.NORMAL);
        ctx.stroke ();
        ctx.restore ();
      }
      return base.draw (ctx);
    }
  }

  public class MenuThrobber: MenuButton
  {
    public bool active { get; set; default = false; }
    private float progress = 0.0f;
    private uint timer_src_id = 0;

    construct
    {
      this.notify["active"].connect (this.active_toggled);
    }

    private void active_toggled ()
    {
      if (active && timer_src_id == 0)
      {
        timer_src_id = Timeout.add (1000 / 30, () =>
        {
          progress += 1.0f / 30;
          if (progress > 1.0f) progress = 0.0f;
          queue_draw ();
          return true;
        });
      }
      else if (!active && timer_src_id != 0)
      {
        Source.remove (timer_src_id);
        timer_src_id = 0;
        progress = 0.0f;
      }
      queue_draw ();
    }

    public override void get_preferred_width (out int min_width, out int nat_width)
    {
      min_width = nat_width = 11;
    }

    public override void get_preferred_height (out int min_height, out int nat_height)
    {
      min_height = nat_height = 11;
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);
    }
    
    public override bool draw (Cairo.Context ctx)
    {
      base.draw (ctx);

      if (!active) return true;

      double r = 0.0, g = 0.0, b = 0.0;
      double SIZE = 0.5;
      double size = button_scale * int.min (this.get_allocated_width (), this.get_allocated_height ()) - SIZE * 2;
      size *= 0.5;
      double xc = this.get_allocated_width () - SIZE * 2 - size;
      double yc = size;
      double arc_start = Math.PI * 2 * progress;
      double arc_end = arc_start + Math.PI / 2.0;

      ch.get_rgb (out r, out g, out b, StyleType.FG, StateFlags.NORMAL, Mod.LIGHTER);
      ctx.set_source_rgb (r, g, b);
      ctx.arc_negative (xc, yc, size * 0.5, arc_end, arc_start);
      ctx.arc (xc, yc, size, arc_start, arc_end);
      ctx.fill ();

      return true;
    }
  }
  
  public class FakeButton: EventBox
  {
    construct
    {
      this.set_events (Gdk.EventMask.BUTTON_RELEASE_MASK |
                       Gdk.EventMask.ENTER_NOTIFY_MASK | 
                       Gdk.EventMask.LEAVE_NOTIFY_MASK);
      this.visible_window = false;
    }
    public override bool enter_notify_event (Gdk.EventCrossing event) 
    {
      enter ();
      return true;
    }
    public override bool leave_notify_event (Gdk.EventCrossing event)
    {
      leave ();
      return true;
    }
    public override bool button_release_event (Gdk.EventButton event)
    {
      released ();
      return true;
    }
    public virtual signal void leave () {}
    public virtual signal void enter () {}
    public virtual signal void released () {}
  }

  public class MenuButton: FakeButton
  {
    public double button_scale { get; set; default = 1.0; }
    private bool entered;
    protected Utils.ColorHelper ch;
    private Gtk.Menu menu;
    public MenuButton ()
    {
      ch = Utils.ColorHelper.get_default ();
      entered = false;
      menu = new Gtk.Menu ();
      Gtk.MenuItem item = null;
      
      item = new Gtk.ImageMenuItem.from_stock (Gtk.Stock.PREFERENCES, null);
      item.activate.connect (()=> {settings_clicked ();});
      menu.append (item);
      
      item = new ImageMenuItem.from_stock (Gtk.Stock.ABOUT, null);
      item.activate.connect (()=> 
      {
        var about = new SynapseAboutDialog ();
        about.run ();
        about.destroy ();
      });
      menu.append (item);
      
      item = new Gtk.SeparatorMenuItem ();
      menu.append (item);
      
      item = new ImageMenuItem.from_stock (Gtk.Stock.QUIT, null);
      item.activate.connect (Gtk.main_quit);
      menu.append (item);
      
      menu.show_all ();
    }
    
    public Gtk.Menu get_menu ()
    {
      return menu;
    }
    
    public override void enter ()
    {
      entered = true;
      this.queue_draw ();
    }
    public override void leave ()
    {
      entered = false;
      this.queue_draw ();
    }
    public bool is_menu_visible ()
    {
      return menu.visible;
    }
    public override void released ()
    {
      menu.popup (null, null, null, 1, 0);
    }
    public signal void settings_clicked ();
    public override void size_allocate (Gtk.Allocation allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);
    }

    public override void get_preferred_width (out int min_width, out int nat_width)
    {
      min_width = nat_width = 11;
    }

    public override void get_preferred_height (out int min_height, out int nat_height)
    {
      min_height = nat_height = 11;
    }
    
    public override bool draw (Cairo.Context ctx)
    {
      double SIZE = 0.5;
      ctx.translate (SIZE, SIZE);
      ctx.set_operator (Cairo.Operator.OVER);
      
      double r = 0.0, g = 0.0, b = 0.0;
      double size = button_scale * int.min (this.get_allocated_width (), this.get_allocated_height ()) - SIZE * 2;
      
      Pattern pat;
      pat = new Pattern.linear (0, 0, 0, this.get_allocated_height ());
      if (entered || this.get_state_flags () == StateFlags.SELECTED)
      {
        ch.get_rgb (out r, out g, out b, StyleType.BG, StateFlags.SELECTED);
      }
      else
      {
        ch.get_rgb (out r, out g, out b, StyleType.BG, StateFlags.NORMAL);
      }
      pat.add_color_stop_rgb (0.0,
                              double.max(r - 0.15, 0),
                              double.max(g - 0.15, 0),
                              double.max(b - 0.15, 0));
      if (entered)
      {
        ch.get_rgb (out r, out g, out b, StyleType.BG, StateFlags.NORMAL);
      }
      pat.add_color_stop_rgb (1.0,
                              double.min(r + 0.15, 1),
                              double.min(g + 0.15, 1),
                              double.min(b + 0.15, 1));

      size *= 0.5;
      double xc = this.get_allocated_width () - SIZE * 2 - size;
      double yc = size;
      ctx.set_source (pat);
      ctx.arc (xc, yc, size, 0.0, Math.PI * 2);
      ctx.fill ();

      if (entered)
      {
        ch.get_rgb (out r, out g, out b, StyleType.FG, StateFlags.NORMAL);
      }
      else
      {
        ch.get_rgb (out r, out g, out b, StyleType.BG, StateFlags.NORMAL);
      }
      
      ctx.set_source_rgb (r, g, b);
      ctx.arc (xc, yc, size * 0.5, 0.0, Math.PI * 2);
      ctx.fill ();

      return true;
    }
  }

  public class SynapseAboutDialog: Gtk.AboutDialog
  {
    public SynapseAboutDialog ()
    {
      string[] devs = {"Michal Hruby <michal.mhr@gmail.com>",
                       "Alberto Aldegheri <albyrock87+dev@gmail.com>",
                       "Tom Beckmann <tom@elementaryos.org>"};
      string[] artists = devs;
      artists += "Ian Cylkowski <designbyizo@gmail.com>";
      GLib.Object (artists : artists,
                   authors : devs,
                   copyright : "Copyright (C) 2010-2013 " + string.joinv ("\n", devs),
                   program_name: "Synapse",
                   logo_icon_name : "synapse",
                   version: Config.VERSION,
                   website: "http://launchpad.net/synapse-project");
    }
  }
  
  public class HTextSelector : EventBox
  {
    private const int ARROW_SIZE = 7;
    public string selected_markup {get; set; default = "<span size=\"medium\"><b>%s</b></span>";}
    public string unselected_markup {get; set; default = "<span size=\"small\">%s</span>";}
    public int padding {get; set; default = 18;}
    public bool show_arrows {get; set; default = true;}
    public bool animation_enabled {get; set; default = true;}
    private class PangoReadyText
    {
      public string text {get; set; default = "";}
      public int offset {get; set; default = 0;}
      public int width {get; set; default = 0;}
      public int height {get; set; default = 0;}
    }
    private int _selected;
    public int selected {get {return _selected;} set {
      if (value == _selected ||
          value < 0 ||
          value >= texts.size)
        return;
      _selected = value;
      update_all_sizes ();
      update_cached_surface ();
      queue_draw ();
      if (!animation_enabled)
      {
        update_current_offset ();
        return;
      }
      if (tid == 0)
      {
        tid = Timeout.add (30, ()=>{
          return update_current_offset ();
        });
      }
    }}
    private Gee.List<PangoReadyText> texts;
    private Cairo.Surface cached_surface;
    private int wmax;
    private int hmax;
    private int current_offset;
    private Utils.ColorHelper ch;
    private Label label;
    
    public HTextSelector ()
    {
      this.above_child = false;
      this.set_has_window (false);
      this.visible_window = false;
      this.label = new Label ("");
      this.label.show ();
      this.add (label);
      this.set_events (Gdk.EventMask.BUTTON_PRESS_MASK |
                       Gdk.EventMask.SCROLL_MASK);
      ch = Utils.ColorHelper.get_default ();
      cached_surface = null;
      tid = 0;
      wmax = hmax = current_offset = 0;
      texts = new Gee.ArrayList<PangoReadyText> ();
      this.label.style_updated.connect (()=>{
        update_all_sizes ();
        update_cached_surface ();
        queue_resize ();
        queue_draw ();
      });
      this.size_allocate.connect (()=>{
        if (tid == 0)
          tid = Timeout.add (30, ()=>{
            return update_current_offset ();
          });
      });
      this.notify["sensitive"].connect (()=>{
        update_cached_surface ();
        queue_draw ();
      });
      this.realize.connect (this._global_update);
      this.notify["selected-markup"].connect (_global_update);
      this.notify["unselected-markup"].connect (_global_update);
      _selected = 0;
      
      var config = (UIWidgetsConfig) ConfigService.get_default ().get_config ("ui", "widgets", typeof (UIWidgetsConfig));
      animation_enabled = config.animation_enabled;
    }
    public override bool button_press_event (Gdk.EventButton event)
    {
      int x = (int)event.x;
      x -= current_offset;
      if (x < 0)
      {
        this.selected = 0;
        selection_changed ();
        return false;
      }
      int i = 0;
      while (i < texts.size && texts.get (i).offset < x) i++;
      this.selected = i - 1;
      selection_changed ();
      return false;
    }
    
    public override bool scroll_event (Gdk.EventScroll event)
    {
      if (event.direction == Gdk.ScrollDirection.UP)
        select_prev ();
      else
        select_next ();
      selection_changed ();
      return true;
    }
    
    public signal void selection_changed ();
    
    public void add_text (string txt)
    {
      texts.add (new PangoReadyText(){
        text = txt,
        offset = 0,
        width = 0,
        height = 0
      });
      _global_update ();
    }

    public void remove_text (int i)
    {
      return_if_fail (i > 0 && i < texts.size);
      return_if_fail (texts.size == 1);
      texts.remove_at (i);
      _global_update ();
      if (selected >= texts.size) selected = texts.size - 1;
    }
    private void _global_update ()
    {
      update_all_sizes ();
      update_cached_surface ();
      queue_resize ();
      queue_draw ();
    }
    private void update_all_sizes ()
    {
      // also updates offsets
      int w = 0, h = 0;
      wmax = hmax = 0;
      string s;
      PangoReadyText txt = null;
      int lastx = 0;
      var layout = this.label.get_layout ();
      for (int i = 0; i < texts.size; i++)
      {
        txt = texts.get (i);
        if (txt == null) continue;
        s = Markup.printf_escaped (i == _selected ? selected_markup : unselected_markup, txt.text);
        layout.set_markup (s, -1);
        layout.get_pixel_size (out w, out h);
        txt.width = w;
        txt.height = h;
        txt.offset = lastx;
        lastx += w + padding;
        wmax = int.max (wmax , txt.width);
        hmax = int.max (hmax, txt.height);
      }
    }
    public override void get_preferred_width (out int min_width, out int nat_width)
    {
      min_width = nat_width = wmax * 3; //triple for fading
    }
    public override void get_preferred_height (out int min_height, out int nat_height)
    {
      min_height = nat_height = hmax;
    }
    public void select_prev ()
    {
      selected = selected - 1;
    }
    public void select_next ()
    {
      selected = selected + 1;
    }
    private void update_cached_surface ()
    {
      if (!this.get_realized ()) return;
      int w = 0, h = 0;
      PangoReadyText txt;
      txt = texts.last ();
      w = txt.offset + txt.width;
      h = hmax * 3; //triple h for nice vertical placement
      var window_context = Gdk.cairo_create (this.get_window ());
      this.cached_surface = new Surface.similar (window_context.get_target (), Cairo.Content.COLOR_ALPHA, w, h);
      var ctx = new Cairo.Context (this.cached_surface);

      var layout = this.label.get_layout ();
      Pango.cairo_update_context (ctx, layout.get_context ());
      ch.set_source_rgba (ctx, 1.0, StyleType.FG, this.get_state_flags ());
      ctx.set_operator (Cairo.Operator.OVER);
      string s;
      for (int i = 0; i < texts.size; i++)
      {
        txt = texts.get (i);
        if (txt == null)
          continue;
        ctx.save ();
        ctx.translate (txt.offset, (h - txt.height) / 2);
        s = Markup.printf_escaped (i == _selected ? selected_markup : unselected_markup, txt.text);
        layout.set_markup (s, -1);
        Pango.cairo_show_layout (ctx, layout);
        ctx.restore ();
      }
      /* Arrows */
      if (!this.show_arrows)
        return;
      if (this.get_state_flags () == StateFlags.SELECTED)
        ch.set_source_rgba (ctx, 1.0, StyleType.BG, StateFlags.NORMAL);
      else
        ch.set_source_rgba (ctx, 1.0, StyleType.BG, StateFlags.SELECTED);
      txt = texts.get (_selected);
      double asize = double.min (ARROW_SIZE, h);
      double px, py = h / 2;
      double f = 2; //curvature
      f = asize - f;
      if (_selected < texts.size - 1)
      {
        px = txt.offset + txt.width + asize + (padding-asize) / 2;
        ctx.move_to (px, py);
        ctx.rel_line_to (-asize, -asize/2);
        ctx.curve_to (px - f, py, px - f, py, px - asize, py + asize / 2);
        ctx.line_to (px, py);
        ctx.fill ();
      }
      if (_selected > 0)
      {
        px = txt.offset - asize - (padding-asize) / 2;
        ctx.move_to (px, py);
        ctx.rel_line_to (asize, -asize/2);
        ctx.curve_to (px + f, py, px + f, py, px + asize, py + asize / 2);
        ctx.line_to (px, py);
        ctx.fill ();
      }
    }
    private uint tid;
    private bool update_current_offset ()
    {
      double draw_offset = 0; //target offset
      PangoReadyText txt = texts.get (_selected);
      draw_offset = this.get_allocated_width () / 2 - txt.offset - txt.width / 2;
      int target = (int)Math.round (draw_offset);
      if (!animation_enabled)
      {
        current_offset = target;
        queue_draw ();
        return false;
      }
      if (target == current_offset)
      {
        tid = 0;
        return false; // stop animation
      }
      int inc = int.max (1, (int) Math.fabs ((target - current_offset) / 6));
      current_offset += target > current_offset ? inc : - inc;
      queue_draw ();
      return true;
    }
    protected override bool draw (Cairo.Context ctx)
    {
      if (texts.size == 0 || this.cached_surface == null)
        return true;
      double w = this.get_allocated_width ();
      double h = this.get_allocated_height ();
      
      ctx.set_operator (Cairo.Operator.OVER);
      double x, y;
      x = current_offset;
      y = Math.round ((h - (3 * hmax)) / 2 );
      ctx.set_source_surface (this.cached_surface, x, y);
      ctx.rectangle (0, 0, w, h);
      ctx.clip ();
      var pat = new Pattern.linear (0, 0, w, h);
      double fadepct = wmax / (double)w;
      if (w / 3 < wmax)
        fadepct = (w - wmax) / 2 / (double)w;
      pat.add_color_stop_rgba (0, 1, 1, 1, 0);
      pat.add_color_stop_rgba (fadepct, 1, 1, 1, 1);
      pat.add_color_stop_rgba (1 - fadepct, 1, 1, 1, 1);
      pat.add_color_stop_rgba (1, 1, 1, 1, 0);
      ctx.mask (pat);
      return true;
    }
  }
}
