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


  public class ContainerOverlayed: Gtk.Container
  {
    private Widget widgets[5];
    private float scale[5];

    public enum Position
    {
      MAIN,
      TOP_LEFT,
      TOP_RIGHT,
      BOTTOM_RIGHT,
      BOTTOM_LEFT
    }

    public ContainerOverlayed ()
    {
      scale = {0, 0.5f, 0.5f, 0.5f, 0.5f};
      widgets = {null, null, null, null, null};
      set_has_window(false);
      set_redraw_on_allocate(false);
    }
    public void set_scale_for_pos (float s, Position pos)
    {
      if (pos == Position.MAIN)
        return;
      if (s != scale[pos])
      {
        scale[pos] = float.max (0.0f, float.min (0.5f, s));
        this.queue_resize ();
      }
    }
    public override void size_request (out Requisition requisition)
    {
      if (widgets[Position.MAIN] != null)
      {
        widgets[Position.MAIN].size_request (out requisition);
        return;
      }
      Requisition req = {0, 0};
      for (int i = 1; i < 5; ++i)
      {
        if (widgets[i] != null)
        {
          widgets[i].size_request (out req);
          requisition.width = int.max (requisition.width, req.width);
          requisition.height = int.max (requisition.height, req.height);
        }
      }
    }
    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);    
      if (widgets[Position.MAIN] != null)
      {
        widgets[Position.MAIN].size_allocate (allocation);
      }
      if (widgets[Position.TOP_LEFT] != null)
      {
        allocation.width = (int)(alloc.width * scale[Position.TOP_LEFT]);
        allocation.height = (int)(alloc.height * scale[Position.TOP_LEFT]);
        widgets[Position.TOP_LEFT].size_allocate (allocation);
      }
      if (widgets[Position.TOP_RIGHT] != null)
      {
        allocation.width = (int)(alloc.width * scale[Position.TOP_RIGHT]);
        allocation.height = (int)(alloc.height * scale[Position.TOP_RIGHT]);
        allocation.x = alloc.x + alloc.width - allocation.width;
        widgets[Position.TOP_RIGHT].size_allocate (allocation);
      }
      if (widgets[Position.BOTTOM_RIGHT] != null)
      {
        allocation.width = (int)(alloc.width * scale[Position.BOTTOM_RIGHT]);
        allocation.height = (int)(alloc.height * scale[Position.BOTTOM_RIGHT]);
        allocation.x = alloc.x + alloc.width - allocation.width;
        allocation.y = alloc.y + alloc.height - allocation.height;
        widgets[Position.BOTTOM_RIGHT].size_allocate (allocation);
      }
      if (widgets[Position.BOTTOM_LEFT] != null)
      {
        allocation.width = (int)(alloc.width * scale[Position.BOTTOM_LEFT]);
        allocation.height = (int)(alloc.height * scale[Position.BOTTOM_LEFT]);
        allocation.x = alloc.x;
        allocation.y = alloc.y + alloc.height - allocation.height;
        widgets[Position.BOTTOM_LEFT].size_allocate (allocation);
      }
    }
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      for (int i = 0; i < 5; ++i)
      {
        if (widgets[i] != null)
          callback (widgets[i]);
      }
    }
    public void set_widget_in_position (Widget widget, Position pos)
    {
      if (widgets[pos] != null)
        widgets[pos].unparent ();
      widgets[pos] = widget;
      if (widget != null)
        widget.set_parent (this);
    }
    public void swapif (Widget w, Position pos1, Position pos2)
    {
      if (widgets[pos1] == w)
        swap (pos1, pos2);
    }
    public void swap (Position pos1, Position pos2)
    {
      Widget t = widgets[pos1];
      widgets[pos1] = widgets[pos2];
      widgets[pos2] = t;
    }

    public override void add (Widget widget)
    {
      //TODO
    }
    public override void remove (Widget widget)
    {
      //TODO
    }
  }
  
  /* HSelectionContainer */
  public class HSelectionContainer: Gtk.Container
  {
    public delegate void SelectWidget (Widget w, bool select);
    private ArrayList<Widget> childs;
    
    private SelectWidget func;
    private int padding;
    private int selection = 0;
    private int[] allocations = {};
    private bool[] visibles = {};
    private bool direction = true;
    private HSeparator sep;
    private Label left;
    private Label right;
    private bool show_arrows;
    
    public enum SelectionAlign
    {
      LEFT = 0,
      CENTER = 1,
      RIGHT = 2
    }
    private int align;
    
    
    public HSelectionContainer (SelectWidget? func, int padding)
    {
      this.func = func;
      this.padding = padding;
      this.align = SelectionAlign.CENTER;
      childs = new ArrayList<Widget>();
      set_has_window(false);
      set_redraw_on_allocate(false);
      sep = new HSeparator();
      sep.set_parent (this);
      sep.show ();
      show_arrows = false;
      left = new Label (null);
      left.set_markup ("<span size=\"small\">&lt;&lt;</span>");
      left.set_parent (this);
      left.sensitive = false;
      right = new Label (null);
      right.set_markup ("<span size=\"small\">&gt;&gt;</span>");
      right.set_parent (this);
      right.sensitive = false;
    }
    
    public void set_arrows_visible (bool b)
    {
      show_arrows = b;
      this.queue_resize ();
    }
    
    public void set_separator_visible (bool b)
    {
      sep.set_visible (b);
      this.queue_resize ();
    }
    
    public void set_selection_align (SelectionAlign align)
    {
      this.align = align;
    }
    
    public void select_next_circular ()
    {
      int sel = selection;
      sel += direction ? 1 : -1;
      if (sel < 0)
      {
        sel = 1;
        direction = true;
      }
      else if (sel >= childs.size)
      {
        sel = childs.size - 2;
        direction = false;
      }
      select (sel);
    }
    public void select_next () {select(selection+1);}
    public void select_prev () {select(selection-1);}
    
    public void select (int index)
    {
      if (index < 0 || childs.size <= index)
        return;
      
      if (func != null)
      {
        func (childs.get(selection), false);
        func (childs.get(index), true);
      }
      this.selection = index;
      this.queue_resize();
      foreach (Widget w in childs)
        w.queue_draw();
    }
    
    public int get_selected ()
    {
      return selection;
    }
    
    public override void size_request (out Requisition requisition)
    {
      Requisition req = {0, 0};
      requisition.width = 1;
      requisition.height = 1;
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        requisition.width = int.max(req.width, requisition.width);
        requisition.height = int.max(req.height, requisition.height);
      }
      left.size_request (out req);
      if (show_arrows)
      {
        requisition.width += req.width * 2 + padding * 2;
        requisition.height = int.max (req.height, requisition.height);
      }
      sep.size_request (out req);
      if (sep.visible)
        requisition.height += req.height * 2;
    }

    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);
      int lastx = 0;
      int min_x = 0;
      int max_x = allocation.width;
      Requisition req = {0, 0};
      sep.size_request (out req);
      int sep_space = sep.visible ? req.height * 2 : 0;
      if (show_arrows)
      {
        left.size_request (out req);
        lastx = req.width + padding;
        max_x = max_x - req.width - padding;
        min_x = lastx;
        allocation.x = alloc.x;
        allocation.y = alloc.y + (alloc.height - sep_space - req.height) / 2;
        allocation.height = req.height;
        allocation.width = req.width;
        left.size_allocate (allocation);
        right.size_request (out req);
        allocation.x = alloc.x + max_x + padding;
        allocation.y = alloc.y + (alloc.height - sep_space - req.height) / 2;
        allocation.height = req.height;
        allocation.width = req.width;
        right.size_allocate (allocation);
      }
      int i = 0;
      // update relative coords
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        this.allocations[i] = lastx;
        lastx += padding + req.width;
        ++i;
      }
      int offset = 0;
      switch (this.align)
      {
        case SelectionAlign.LEFT:
          offset = - allocations[selection];
          break;
        case SelectionAlign.RIGHT:
          offset = max_x - allocations[selection];
          childs.get (selection).size_request (out req);
          offset -= req.width;
          break;
        default:
          offset = alloc.width / 2 - allocations[selection];
          childs.get (selection).size_request (out req);
          offset -= req.width / 2;
          break;
      }
      // update widget allocations and visibility
      i = 0;
      int pos = 0;
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        pos = offset + allocations[i];
        if (pos < min_x || pos + req.width > max_x)
        {
          visibles[i] = false;
          w.hide ();
        }
        else
        {
          visibles[i] = true;
          allocation.x = alloc.x + pos;
          allocation.width = req.width;
          allocation.height = req.height;
          allocation.y = alloc.y + (alloc.height - sep_space - req.height) / 2;
          w.size_allocate (allocation);
          w.show_all ();
        }
        ++i;
      }
      left.visible = show_arrows && (!visibles[0]);
      right.visible = show_arrows && (!visibles[childs.size - 1]);
      allocation.x = alloc.x;
      allocation.y = alloc.y + alloc.height - sep_space * 3 / 2;
      allocation.height = sep_space;
      allocation.width = alloc.width;
      sep.size_allocate (allocation);
    }
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      int i = 0;
      if (b)
      {
        callback (sep);
        callback (left);
        callback (right);
      }
      if (childs.size == 0)
        return;
      if (this.align == SelectionAlign.LEFT)
      {
        for (i = childs.size - 1; i >= 0; ++i)
        {
          if ( visibles[i] )
            callback (childs.get(i));
        }
      }
      else if (this.align == SelectionAlign.RIGHT)
      {
        foreach (Widget w in childs)
        {
          if ( visibles[i] )
            callback (w);
          ++i;
        }
      }
      else //align center
      {
        int j;
        j = i = selection;
        ArrayList<Widget> reordered = new ArrayList<Widget>();
        reordered.add (childs.get(i));
        while (j >= 0 || i < childs.size)
        {
          --j;
          ++i;
          if (j >= 0)
            reordered.add (childs.get(j));
          if (i < childs.size)
            reordered.add (childs.get(i));
        }
        for (i = reordered.size - 1; i >= 0; --i)
          callback (reordered.get(i));
      }
    }

    public override void add (Widget widget)
    {
      childs.add (widget);
      widget.set_parent (this);
      this.allocations += 0;
      this.visibles += true;
      if (childs.size==1)
      {
        this.selection = 0;
        if (func != null)
          func (widget, true);
      }
      else if (func != null)      
        func (widget, false);
    }
    
    public override void remove (Widget widget)
    {
      if (childs.remove (widget))
      {
        widget.unparent ();
        this.allocations.resize (this.allocations.length);
        this.visibles.resize (this.visibles.length);
      }
    }
  }
  public class Throbber: Spinner
  {
    construct
    {
      this.notify["active"].connect (this.queue_draw);
    }

    public override bool expose_event (Gdk.EventExpose event)
    {
      if (this.active)
      {
        return base.expose_event (event);
      }
      return true;
    }
  }
  public class NamedIcon: Gtk.Image
  {
    public string not_found_name {get; set; default = "unknown";}
    private string current;
    private IconSize current_size;
    private uint tid; //for timer
    private Utils.ColorHelper ch;
    public int update_timeout {get; set; default = -1;}
    public bool stop_prev_timeout {get; set; default = false;}
    public bool glow {get; set; default = false;}
    public NamedIcon ()
    {
      current = "";
      current_size = IconSize.DIALOG;
      tid = 0;
      ch = new Utils.ColorHelper (this);
      this.notify["glow"].connect (this.queue_draw);
    }
    public override bool expose_event (Gdk.EventExpose event)
    {
      if (glow)
      {
        var ctx = Gdk.cairo_create (this.window);
        ctx.set_operator (Cairo.Operator.OVER);

        /* Prepare bg's colors using GtkStyle */
        double xc = this.allocation.x + this.allocation.width / 2;
        double yc = this.allocation.y + this.allocation.height / 2;
        double rad = double.min ( this.allocation.height, this.allocation.width ) / 2.0;
        Pattern pat = new Pattern.radial (xc, yc, 0, xc, yc, rad);
        ch.add_color_stop_rgba (pat, 0.7, 1.0, ch.StyleType.BASE, StateType.SELECTED);
        ch.add_color_stop_rgba (pat, 1, 0, ch.StyleType.BASE, StateType.SELECTED);
        /* Prepare and draw top bg's rect */
        ctx.rectangle (xc - rad, yc - rad, 2*rad, 2*rad);
        ctx.set_source (pat);
        ctx.clip ();
        ctx.paint ();
      }
      return base.expose_event (event);
    }
    public new void clear ()
    {
      if (tid != 0)
      {
        Source.remove (tid);
        tid = 0;
      }
      current = "";
      base.clear ();
    }
    public void set_icon_name (string? name, IconSize size)
    {
      if (name == null)
        name = "";
      if (name == current)
        return;
      else
      {
        if (name == "")
        {
          name = not_found_name;
        }
        current = name;
        current_size = size;
        if (update_timeout <= 0)
        {
          real_update_image ();
        }
        else
        {
          if (tid != 0 && stop_prev_timeout)
          {
            Source.remove (tid);
            tid = 0;
          }
          if (tid == 0)
          {
            base.clear ();
            tid = Timeout.add (update_timeout,
              () => {tid = 0; real_update_image (); return false;}
            );
          }
        }
      }
    }
    private void real_update_image ()
    {
      try
      {
        var icon = GLib.Icon.new_for_string (current);
        //make sure that it exist in the icon theme
        var iconinfo = Gtk.IconTheme.get_default ().lookup_by_gicon (icon, 32, 0);
        if (iconinfo == null)
          throw new WidgetError.ICON_NOT_FOUND ("Requested icon could not be found.");
        this.set_from_gicon (icon, current_size);
      }
      catch (Error err)
      {
        if (current != not_found_name)
        {
          if (not_found_name == "")
            this.clear ();
          else
            this.set_from_icon_name (not_found_name, current_size);
          current = not_found_name;
        }
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
      ch = new Utils.ColorHelper (this);
      this.notify["draw-input"].connect (this.queue_draw);
      this.notify["input-alpha"].connect (this.queue_draw);
      this.notify["border-radius"].connect (this.queue_draw);
      this.notify["shadow-pct"].connect (this.queue_draw);
      this.notify["focus-height"].connect (this.queue_draw);
    }

    public override bool expose_event (Gdk.EventExpose event)
    {
      if (draw_input)
      {
        var ctx = Gdk.cairo_create (this.window);
        ctx.translate (1.5, 1.5);
        ctx.set_operator (Cairo.Operator.OVER);
        ctx.set_line_width (1.25);

        double x = this.allocation.x + this.left_padding,
               y = this.allocation.y + this.top_padding,
               w = this.allocation.width - this.left_padding - this.right_padding - 3.0,
               h = this.allocation.height - this.top_padding - this.bottom_padding - 3.0;
        Utils.cairo_rounded_rect (ctx, x, y, w, h, border_radius);
        if (!ch.is_dark_color (ch.StyleType.FG, StateType.NORMAL))
          ch.set_source_rgba (ctx, input_alpha, ch.StyleType.BG, StateType.NORMAL, ch.Mod.DARKER);
        else
          ch.set_source_rgba (ctx, input_alpha, ch.StyleType.FG, StateType.NORMAL, ch.Mod.INVERTED);
        Cairo.Path path = ctx.copy_path ();
        ctx.save ();
        ctx.clip ();
        ctx.paint ();
        var pat = new Cairo.Pattern.linear (0, y, 0, y + shadow_height);
        ch.add_color_stop_rgba (pat, 0, 0.6 * input_alpha, ch.StyleType.FG, StateType.NORMAL);
        ch.add_color_stop_rgba (pat, 0.3, 0.25 * input_alpha, ch.StyleType.FG, StateType.NORMAL);
        ch.add_color_stop_rgba (pat, 1.0, 0, ch.StyleType.FG, StateType.NORMAL);
        ctx.set_source (pat);
        ctx.paint ();
        if (_focus_widget != null)
        {
          /*
                     ____            y1
                  .-'    '-.
               .-'          '-.
            .-'                '-.
           x1         x2         x3  y2
          */
          double x1 = double.max (_focus_widget.allocation.x, x),
                 x3 = double.min (_focus_widget.allocation.x + _focus_widget.allocation.width,
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
          ch.add_color_stop_rgba (pat, 0, 1.0 * input_alpha, ch.StyleType.BG, StateType.SELECTED);
          ch.add_color_stop_rgba (pat, 1, 0, ch.StyleType.BG, StateType.SELECTED);
          ctx.set_source (pat);
          ctx.paint ();
        }
        ctx.restore ();
        ctx.append_path (path);
        ch.set_source_rgba (ctx, 0.6 * input_alpha, ch.StyleType.FG, StateType.NORMAL);
        ctx.stroke ();
      }
      return base.expose_event (event);
    }
  }
  public class MenuThrobber: MenuButton
  {
    private Gtk.Spinner throbber;
    public bool active {get; set; default = false;}
    construct
    {
      throbber = new Gtk.Spinner ();
      throbber.active = false;
      this.notify["active"].connect ( ()=>{
        throbber.active = active;
        queue_draw ();
      } );
      
      this.add (throbber);
    }
    public override void size_request (out Requisition requisition)
    {
      requisition.width = 11;
      requisition.height = 11;
    }
    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);
      int min = int.min (allocation.width, allocation.height);
      allocation.x = allocation.x + allocation.width - min;
      allocation.height = allocation.width = min;
      throbber.size_allocate (allocation);
    }
    
    public override bool expose_event (Gdk.EventExpose event)
    {
      if (this.active)
      {
        /* Propagate Expose */               
        Bin c = (this is Bin) ? (Bin) this : null;
        if (c != null)
          c.propagate_expose (this.get_child(), event);
      }
      else
      {
        base.expose_event (event);
      }
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
    private Gtk.Menu menu;
    private bool entered;
    public double button_scale {get; set; default = 0.5;}
    private Utils.ColorHelper ch;
    public MenuButton ()
    {
      ch = new Utils.ColorHelper (this);
      entered = false;
      menu = new Gtk.Menu ();
      Gtk.MenuItem item = null;
      
      item = new Gtk.ImageMenuItem.from_stock (Gtk.STOCK_PREFERENCES, null);
      item.activate.connect (()=> {settings_clicked ();});
      menu.append (item);
      
      item = new ImageMenuItem.from_stock (Gtk.STOCK_ABOUT, null);
      item.activate.connect (()=> 
      {
        var about = new SynapseAboutDialog ();
        about.run ();
        about.destroy ();
      });
      menu.append (item);
      
      item = new Gtk.SeparatorMenuItem ();
      menu.append (item);
      
      item = new ImageMenuItem.from_stock (Gtk.STOCK_QUIT, null);
      item.activate.connect (Gtk.main_quit);
      menu.append (item);
      
      menu.show_all ();
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
    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);
    }
    public override void size_request (out Requisition requisition)
    {
      requisition.width = 11;
      requisition.height = 11;
    }
    
    public override bool expose_event (Gdk.EventExpose event)
    {
      var ctx = Gdk.cairo_create (this.window);
      double SIZE = 0.5;
      ctx.translate (SIZE, SIZE);
      ctx.set_operator (Cairo.Operator.OVER);
      
      double r = 0.0, g = 0.0, b = 0.0;
      double size = button_scale * int.min (this.allocation.width, this.allocation.height) - SIZE * 2;

      
      Pattern pat;
      pat = new Pattern.linear (this.allocation.x,
                                this.allocation.y,
                                this.allocation.x,
                                this.allocation.y + this.allocation.height);
      if (entered)
      {
        ch.get_rgb (out r, out g, out b, ch.StyleType.BG, StateType.SELECTED);
      }
      else
      {
        ch.get_rgb (out r, out g, out b, ch.StyleType.BG, StateType.NORMAL);
      }
      pat.add_color_stop_rgb (0.0,
                              double.max(r - 0.15, 0),
                              double.max(g - 0.15, 0),
                              double.max(b - 0.15, 0));
      if (entered)
      {
        ch.get_rgb (out r, out g, out b, ch.StyleType.BG, StateType.NORMAL);
      }
      pat.add_color_stop_rgb (1.0,
                              double.min(r + 0.15, 1),
                              double.min(g + 0.15, 1),
                              double.min(b + 0.15, 1));
      
      size *= 0.5;
      ctx.set_source (pat);
      ctx.arc (this.allocation.x + this.allocation.width - SIZE * 2 - size,
               this.allocation.y + size,
               size, 0, Math.PI * 2);
      ctx.fill ();

      if (entered)
      {
        ch.get_rgb (out r, out g, out b, ch.StyleType.FG, StateType.NORMAL);
      }
      else
      {
        ch.get_rgb (out r, out g, out b, ch.StyleType.BG, StateType.NORMAL);
      }
      
      ctx.set_source_rgb (r, g, b);
      ctx.arc (this.allocation.x + this.allocation.width - SIZE * 2 - size,
               this.allocation.y + size,
               size * 0.5, 0, Math.PI * 2);
      ctx.fill ();
      
      return true;
    }
  }

  public class ShrinkingLabel: Gtk.Label
  {
    private const double STEP = 1.0466351393921056; // (1.2)^1/4
    
    public string default_size { get; set; default = "x-large"; }
    public string min_size { get; set; default = "medium"; }
    private double min_scale = 1.0;

    construct
    {
      this.notify["min-size"].connect (this.min_size_changed);
    }
    
    private void min_size_changed ()
    {
      switch (min_size)
      {
        case "xx-small":
          min_scale = Pango.Scale.XX_SMALL;
          break;
        case "x-small":
          min_scale = Pango.Scale.X_SMALL;
          break;
        case "small":
          min_scale = Pango.Scale.SMALL;
          break;
        case "medium":
          min_scale = Pango.Scale.MEDIUM;
          break;
        case "large":
          min_scale = Pango.Scale.LARGE;
          break;
        case "x-large":
          min_scale = Pango.Scale.X_LARGE;
          break;
        case "xx-large":
          min_scale = Pango.Scale.XX_LARGE;
          break;
        default:
          warning ("\"%s\" is not valid for min-size property", min_size);
          min_scale = 1.0;
          break;
      }
    }
    
    private Gtk.Requisition base_req;
    private Gtk.Requisition small_req;
    
    protected override void size_request (out Gtk.Requisition req)
    {
      req.width = base_req.width;
      req.height = base_req.height;
    }

    protected override void size_allocate (Gdk.Rectangle alloc)
    {
      base.size_allocate (alloc);
      
      var layout = this.get_layout ();
      Utils.update_layout_rtl (layout, get_default_direction ());
      if (this.get_ellipsize () != Pango.EllipsizeMode.NONE)
      {
        int width = (int) ((alloc.width - this.xpad * 2) * Pango.SCALE);
        Pango.Rectangle logical;
        
        layout.set_width (-1);
        layout.get_extents (null, out logical);

        while (logical.width > width && downscale ())
        {
          layout.get_extents (null, out logical);
        }

        // careful this seems to call layout.set_width
        base.size_request (out small_req);
        
        if (logical.width > width) layout.set_width (width);
      }
    }

    protected override bool expose_event (Gdk.EventExpose event)
    {
      // fool our base class to keep correct align
      this.requisition.width = small_req.width;
      this.requisition.height = small_req.height;

      bool ret = base.expose_event (event);

      this.requisition.width = base_req.width;
      this.requisition.height = base_req.height;

      return ret;
    }
    
    public new void set_markup (string markup)
    {
      base.set_markup ("<span size=\"%s\">%s</span>".printf (default_size,
                                                             markup));
      base.size_request (out base_req);
      small_req = base_req;
      if (this.allocation.width > 1 && this.allocation.height > 1)
      {
        this.size_allocate ((Gdk.Rectangle) this.allocation);
      }
    }
    
    private bool downscale ()
    {
      bool changed = false;
      var context = this.get_layout ();
      var attrs = context.get_attributes ();
      Pango.AttrIterator iter = attrs.get_iterator ();
      do
      {
        unowned Pango.Attribute? attr = iter.get (Pango.AttrType.SCALE);
        if (attr != null)
        {
          unowned Pango.AttrFloat a = (Pango.AttrFloat) attr;
          if (a.value > min_scale)
          {
            a.value /= STEP;
            changed = true;
          }
        }
      } while (iter.next ());
      
      if (changed) context.context_changed (); // force recomputation
      return changed;
    }
    
    public ShrinkingLabel ()
    {
      GLib.Object (label: null);
    }
  }
  public class LabelWithOriginal: Label
  {
    public string original_string {
      get; set; default = "";
    }
  }
  
  public class SynapseAboutDialog: Gtk.AboutDialog
  {
    public SynapseAboutDialog ()
    {
      string[] devs = {"Michal Hruby <michal.mhr@gmail.com>", "Alberto Aldegheri <albyrock87+dev@gmail.com>"};
      string[] artists = devs;
      artists += "Ian Cylkowski <designbyizo@gmail.com>";
      GLib.Object (artists : artists,
                   authors : devs,
                   copyright : "Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>",
                   program_name: "Synapse",
                   logo_icon_name : "synapse",
                   version: Config.VERSION);
    }
  }
  
  public class HTextSelector : Label
  {
    private new Pango.Layout layout;
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
    
    public HTextSelector ()
    {
      ch = new Utils.ColorHelper (this);
      cached_surface = null;
      tid = 0;
      wmax = hmax = current_offset = 0;
      texts = new Gee.ArrayList<PangoReadyText> ();
      layout = this.create_pango_layout (null);
      this.style_set.connect (()=>{
        layout.context_changed ();
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
      this.realize.connect (this._global_update);
      this.notify["selected-markup"].connect (_global_update);
      this.notify["unselected-markup"].connect (_global_update);
      _selected = 0;
      
      var config = (UIWidgetsConfig) ConfigService.get_default ().get_config ("ui", "widgets", typeof (UIWidgetsConfig));
      animation_enabled = config.animation_enabled;
    }
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
    protected override void size_request (out Gtk.Requisition req)
    {
      req.width = wmax * 3; // triple for fading
      req.height = hmax;
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
      var window_context = Gdk.cairo_create (this.window);
      this.cached_surface = new Surface.similar (window_context.get_target (), Cairo.Content.COLOR_ALPHA, w, h);
      var ctx = new Cairo.Context (this.cached_surface);

      Pango.cairo_update_context (ctx, layout.get_context ());
      ch.set_source_rgba (ctx, 1.0, ch.StyleType.FG, StateType.NORMAL);
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
      ch.set_source_rgba (ctx, 1.0, ch.StyleType.BG, StateType.SELECTED);
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
      draw_offset = this.allocation.width / 2 - txt.offset - txt.width / 2;
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
    protected override bool expose_event (Gdk.EventExpose event)
    {
      if (texts.size == 0 || this.cached_surface == null)
        return true;
      var ctx = Gdk.cairo_create (this.window);
      ctx.translate (this.allocation.x, this.allocation.y);
      double w = this.allocation.width;
      double h = this.allocation.height;
      
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
