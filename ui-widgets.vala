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
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 * 
 *
 */

using Gtk;
using Cairo;
using Gee;

public static extern void gtk_style_get_style_property (Style style, Type widget_type, string property_name, out Value val);

namespace Synapse
{
  /* Result List stuff */
  public class ResultBox: EventBox
  {
    private const int VISIBLE_RESULTS = 5;
    private const int ICON_SIZE = 36;
    private int mwidth;
    private int nrows;
    private bool no_results;
    private int items;

    private VBox vbox;
    private HBox status_box;
    
    public ResultBox (int width, int nrows = 5)
    {
      this.mwidth = width;
      this.nrows = nrows;
      items = 0;
      no_results = true;
      build_ui();
    }
    
    private enum Column {
			ICON_COLUMN = 0,
			NAME_COLUMN = 1,
		}
		
		private TreeView view;
		ListStore results;
		private Label status;
		
		private bool on_expose (Widget w, Gdk.EventExpose event) {
        var ctx = Gdk.cairo_create (w.window);
        /* Clear Stage */
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.set_operator (Cairo.Operator.OVER);

        /* Prepare bg's colors using GtkStyle */
        Gtk.Style style = w.get_style();
        double r = 0.0, g = 0.0, b = 0.0;
        Pattern pat = new Pattern.linear(0, 0, 0, w.allocation.height);
        Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], out r, out g, out b);
        pat.add_color_stop_rgba (1.0 - 15.0 / w.allocation.height, double.min(r + 0.15, 1),
                                    double.min(g + 0.15, 1),
                                    double.min(b + 0.15, 1),
                                    0.95);
        pat.add_color_stop_rgba (1, double.max(r - 0.15, 0),
                                    double.max(g - 0.15, 0),
                                    double.max(b - 0.15, 0),
                                    0.95);
        /* Prepare and draw top bg's rect */
        ctx.rectangle (0, 0, w.allocation.width, w.allocation.height);
        ctx.set_source (pat);
        ctx.fill ();

        /* Propagate Expose */               
        Container c = (w is Container) ? (Container) w : null;
        if (c != null)
          c.propagate_expose (this.get_child(), event);
        
        return true;
    }

    private void build_ui()
    {
      view = new TreeView ();
      
      vbox = new VBox (false, 0);
      this.expose_event.connect (on_expose);
      vbox.border_width = 0;
      this.add (vbox);
      vbox.pack_start (view);
      status_box = new HBox (false, 0);
      status_box.set_size_request (-1, 15);
      vbox.pack_start (status_box, false);
      status = new Label (null);
      status.set_alignment (0, 0);
      status.set_markup (Markup.printf_escaped ("<b>%s</b>", "No results."));
      var logo = new Label (null);
      logo.set_alignment (1, 0);
      logo.set_markup (Markup.printf_escaped ("<i>Synapse</i>"));
      status_box.pack_start (status, false, false, 10);
      status_box.pack_start (new Label (null), true, false);
      status_box.pack_start (logo, false, false, 10);
      
			view.enable_search = false;
			view.show_expanders = false;
			view.headers_visible = false;
			view.fixed_height_mode = true; // speedup but use Gtk.TreeViewColumnSizing.FIXED
			view.show();
			view.realize.connect (()=>{
			  /* Block clicks on list */
			  Gdk.EventMask mask = view.get_bin_window ().get_events ();
			  mask = mask & (~Gdk.EventMask.BUTTON_PRESS_MASK);
			  mask = mask & (~Gdk.EventMask.BUTTON_RELEASE_MASK);
			  view.get_bin_window ().set_events (mask);
			});

      view.model = results = new ListStore(2, typeof(GLib.Icon), typeof(string));

      var column = new TreeViewColumn ();
			column.sizing = Gtk.TreeViewColumnSizing.FIXED; // needed for speedup
			column.spacing = 0;

			var crp = new CellRendererPixbuf ();
      crp.stock_size = IconSize.DND;
			var ctxt = new CellRendererText ();
			ctxt.ellipsize = Pango.EllipsizeMode.END;
			ctxt.xpad = 5;

      crp.ypad = 0;
      ctxt.ypad = 0;
      int cellh = ICON_SIZE;
      crp.set_fixed_size (ICON_SIZE, cellh);
      ctxt.set_fixed_size (mwidth - ICON_SIZE, cellh);

			column.pack_start (crp, false);
			column.add_attribute (crp, "gicon", (int) Column.ICON_COLUMN);
			column.pack_start (ctxt, false);
      column.add_attribute (ctxt, "markup", (int) Column.NAME_COLUMN);

      view.append_column (column);
      on_view_style_set (view, null);
      view.style_set.connect (on_view_style_set);
    }
    private void on_view_style_set (Gtk.Widget widget, Gtk.Style? prev_style)
    {
      /* WORKAROUND FOR ROW HEIGHT */
      Requisition requisition = {0, 0};
      TreeIter iter;
      results.append (out iter);
      results.set (iter, Column.ICON_COLUMN, null, Column.NAME_COLUMN, "");
      view.size_request (out requisition);
      results.remove (iter);
      int cellh = requisition.height / (items + 1);
      status_box.size_request (out requisition);
      requisition.width = mwidth;
      requisition.height += nrows * cellh;
      vbox.set_size_request (requisition.width, requisition.height);
      this.queue_resize ();
      this.queue_draw ();
    }

    public void update_matches (Gee.List<Synapse.Match>? rs)
    {
      results.clear();
      if (rs==null || rs.size == 0)
      {
        no_results = true;
        items = 0;
        status.set_markup (Markup.printf_escaped ("<b>%s</b>", "No results."));
        return;
      }
      items = rs.size;
      no_results = false;
      string desc;
      TreeIter iter;
      GLib.Icon icon = null;
      foreach (Match m in rs)
      {
        results.append (out iter);
        desc = Utils.replace_home_path_with (m.description, "Home", " > "); // FIXME: i18n
        try {
          icon = GLib.Icon.new_for_string(m.icon_name);
        } catch (GLib.Error err) { icon = null; }
        results.set (iter, Column.ICON_COLUMN, icon, Column.NAME_COLUMN, 
                     Markup.printf_escaped ("<span size=\"medium\"><b>%s</b></span>\n<span size=\"small\">%s</span>",m.title, desc));
      }
      var sel = view.get_selection ();
      sel.select_path (new TreePath.first());
      status.set_markup (Markup.printf_escaped ("<b>1 of %d</b>", results.length));
    }
    public void move_selection_to_index (int i)
    {
      var sel = view.get_selection ();
      if (no_results)
        return;
      Gtk.TreePath path = new TreePath.from_string( i.to_string() );
      /* Scroll to path */
      Timeout.add(1, () => {
          sel.unselect_all ();
          sel.select_path (path);
          view.scroll_to_cell (path, null, true, 0.5F, 0.0F);
          return false;
      });
      status.set_markup (Markup.printf_escaped ("<b>%d of %d</b>", i + 1, results.length));
    }
    public int move_selection (int val, out int old_index)
    {
      if (no_results)
        return -1;
      var sel = view.get_selection ();
      int index = -1, oindex = -1;
      GLib.List<TreePath> sel_paths = sel.get_selected_rows(null);
      TreePath path = sel_paths.first ().data;
      TreePath opath = path;
      oindex = path.to_string().to_int();
      old_index = oindex;
      if (val == 0)
        return oindex;
      if (val > 0)
        path.next ();
      else if (val < 0)
        path.prev ();
      
      index = path.to_string().to_int();
      if (index < 0 || index >= results.length)
      {
        index = oindex;
        path = opath;
      }
      /* Scroll to path */
      Timeout.add(1, () => {
          sel.unselect_all ();
          sel.select_path (path);
          view.scroll_to_cell (path, null, true, 0.5F, 0.0F);
          return false;
      });
      
      return index;
    }
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
      //left.sensitive = false;
      right = new Label (null);
      right.set_markup ("<span size=\"small\">&gt;&gt;</span>");
      right.set_parent (this);
      //right.sensitive = false;
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
        requisition.width += req.width * 2;
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
        lastx = req.width;
        max_x -= req.width;
        min_x += req.width;
        allocation.x = alloc.x;
        allocation.y = alloc.y + (alloc.height - sep_space - req.height) / 2;
        allocation.height = req.height;
        allocation.width = req.width;
        left.size_allocate (allocation);
        right.size_request (out req);
        allocation.x = alloc.x + max_x;
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
    public string not_found_name {get; set; default = "missing-image";}
    private string current;
    private IconSize current_size;
    private uint tid; //for timer
    public int update_timeout {get; set; default = -1;}
    public bool stop_prev_timeout {get; set; default = false;}
    public NamedIcon ()
    {
      current = "";
      current_size = IconSize.DIALOG;
      tid = 0;
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
    public void set_icon_name (string name, IconSize size)
    {
      if (name == current)
        return;
      else
      {
        if (name == "")
        {
          this.clear ();
          current = "";
          return;
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
        this.set_from_gicon (GLib.Icon.new_for_string (current), current_size);
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
    public double border_radius {get; set; default = 3.0;}
    public double shadow_height {get; set; default = 3;}
    public double focus_height {get; set; default = 3;}
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
      this.notify["draw-input"].connect (this.queue_draw);
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
        Gtk.Style style = this.get_style();
        double r = 0.0, g = 0.0, b = 0.0;
        Utils.gdk_color_to_rgb (style.fg[Gtk.StateType.NORMAL], out r, out g, out b);
        double x = this.allocation.x + this.left_padding,
               y = this.allocation.y + this.top_padding,
               w = this.allocation.width - this.left_padding - this.right_padding - 3.0,
               h = this.allocation.height - this.top_padding - this.bottom_padding - 3.0;
        Utils.cairo_rounded_rect (ctx, x, y, w, h, border_radius);
        Utils.rgb_invert_color (ref r, ref g, ref b);
        ctx.set_source_rgba (r, g, b, 1.0);
        Cairo.Path path = ctx.copy_path ();
        ctx.save ();
        ctx.clip ();
        ctx.paint ();
        Utils.rgb_invert_color (ref r, ref g, ref b);
        var pat = new Cairo.Pattern.linear (0, y, 0, y + shadow_height);
        pat.add_color_stop_rgba (0, r, g, b, 0.6);
        pat.add_color_stop_rgba (0.3, r, g, b, 0.25);
        pat.add_color_stop_rgba (1.0, r, g, b, 0);
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
          Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.SELECTED], out r, out g, out b);
          pat = new Cairo.Pattern.linear (0, y2, 0, y1);
          pat.add_color_stop_rgba (0, r, g, b, 1.0);
          pat.add_color_stop_rgba (1, r, g, b, 0.0);
          ctx.set_source (pat);
          ctx.paint ();
        }
        ctx.restore ();
        ctx.append_path (path);
        Utils.gdk_color_to_rgb (style.fg[Gtk.StateType.NORMAL], out r, out g, out b);
        ctx.set_source_rgba (r, g, b, 0.6);
        ctx.stroke ();
      }
      return base.expose_event (event);
    }
  }
  
  public class MenuButton: Button
  {
    private Gtk.Menu menu;
    public MenuButton ()
    {
      menu = new Gtk.Menu ();
      Gtk.MenuItem item = null;
      
      item = new Gtk.MenuItem.with_label ("Settings"); //TODO: i18n
      item.activate.connect (()=> {settings_clicked ();});
      menu.append (item);
      
      item = new Gtk.MenuItem.with_label ("Quit"); //TODO: i18n
      item.activate.connect (Gtk.main_quit);
      menu.append (item);
      
      menu.show_all ();
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
      
      Gtk.Style style = this.get_style();
      double r = 0.0, g = 0.0, b = 0.0;
      Utils.gdk_color_to_rgb (style.fg[Gtk.StateType.INSENSITIVE], out r, out g, out b);
      ctx.set_source_rgba (r, g, b, 1.0);
      
      ctx.new_path ();
      double size = 0.7 * int.min (this.allocation.width, this.allocation.height) - SIZE * 2;
      ctx.move_to (this.allocation.x + this.allocation.width - SIZE * 2 - size, this.allocation.y);
      ctx.rel_line_to (size, size);
      ctx.rel_line_to (0, - size);
      ctx.close_path ();
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
#if VALA_0_12
      Pango.AttrIterator iter = attrs.get_iterator ();
#else
      unowned Pango.AttrIterator iter = attrs.get_iterator (); // FIXME: leaks
#endif
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
}
