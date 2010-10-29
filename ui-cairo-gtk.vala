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
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Cairo;
using Gee;

namespace Sezen
{
  public class SezenWindow: UIInterface
  {
    /* CONSTANTS */
    private const int PADDING = 10;
    private const int BORDER_RADIUS = 10;
    private const int ICON_SIZE = 172;
    private const int ACTION_ICON_SIZE = 64;
    private const int UI_WIDTH = 480 + ACTION_ICON_SIZE*1 + PADDING * 2;
    private const int DESCRIPTION_HEIGHT = 14;
    private const int UI_HEIGHT = ICON_SIZE + PADDING * 2 + DESCRIPTION_HEIGHT;
    private const int UI_LIST_WIDTH = 400;
    private const int UI_LIST_HEIGHT = (35/*icon_size*/ + 4 /*row border*/) * 5 + 15 /*statusbar*/ + 2 /* Result box Border*/;
    private const int LIST_BORDER_RADIUS = 3;
    private const int TOP_SPACING = UI_HEIGHT * 4 / 10;
    
    private string[] categories = {"All", "Applications", "Actions", "Audio", "Video", "Documents", "Images", "Internet"};
    private QueryFlags[] categories_query = {QueryFlags.ALL, QueryFlags.APPLICATIONS, QueryFlags.ACTIONS, QueryFlags.AUDIO, QueryFlags.VIDEO,
                                             QueryFlags.DOCUMENTS, QueryFlags.IMAGES, QueryFlags.INTERNET};

    /* STATUS */
    private bool list_visible = true;
    private IMContext im_context;
    
    private Gtk.Window window;

    public SezenWindow ()
    {
      window = new Gtk.Window ();
      window.set_position (WindowPosition.CENTER);
      window.expose_event.connect (on_expose);
      on_composited_changed (window);
      window.composited_changed.connect (on_composited_changed);
      window.key_press_event.connect (key_press_event);
      window.set_size_request (UI_WIDTH, UI_HEIGHT+UI_LIST_HEIGHT);
      window.set_decorated (false);
      window.set_resizable (false);
      this.build_ui ();
      set_list_visible (false);
      
      /* SEZEN */
      focus_match (0, null);
      focus_action (0, null);

      im_context = new IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (search_add_char);
      im_context.focus_in ();
    }
    
    private void rounded_rect (Cairo.Context ctx, double x, double y, double w, double h, double r)
    {
      double y2 = y+h, x2 = x+w;
      ctx.move_to (x, y2 - r);
      ctx.arc (x+r, y+r, r, Math.PI, Math.PI * 1.5);
      ctx.arc (x2-r, y+r, r, Math.PI * 1.5, Math.PI * 2.0);
      ctx.arc (x2-r, y2-r, r, 0, Math.PI * 0.5);
      ctx.arc (x+r, y2-r, r, Math.PI * 0.5, Math.PI);
    }

    private void get_shape (Cairo.Context ctx, bool mask_for_composited = false)
    {
      ctx.set_source_rgba (0,0,0,1);
      if (mask_for_composited)
      {
        ctx.rectangle (0, 0, UI_WIDTH, UI_HEIGHT + UI_LIST_HEIGHT);
        ctx.fill ();
        return;
      }
      get_shape_main (ctx);
      get_shape_list (ctx);
    }
    
    private void get_shape_main (Cairo.Context ctx)
    {
      rounded_rect (ctx, 0, TOP_SPACING, UI_WIDTH, UI_HEIGHT - TOP_SPACING, BORDER_RADIUS);
      ctx.fill ();
      rounded_rect (ctx, 0, 0,  ICON_SIZE + PADDING * 2, ICON_SIZE, BORDER_RADIUS);
      ctx.fill ();
    }
    
    private void get_shape_list (Cairo.Context ctx)
    {
      if (list_visible)
      {
        rounded_rect (ctx, (UI_WIDTH - UI_LIST_WIDTH) / 2,
                            UI_HEIGHT,
                            UI_LIST_WIDTH,
                            UI_LIST_HEIGHT,
                            LIST_BORDER_RADIUS);
        ctx.fill ();
      }
    }

    private void on_composited_changed (Widget w)
    {
      bool is_composited = true;
      Gdk.Colormap? cm = w.get_screen ().get_rgba_colormap();
      if (cm == null)
      {
        is_composited = false;
        cm = w.get_screen ().get_rgb_colormap();
      }
      w.set_colormap (cm);
      if (is_composited)
        set_mask (true);
      set_mask ();
    }
    
    public static void color_to_rgb (Gdk.Color col, double *r, double *g, double *b)
    {
      *r = col.red / (double)65535;
      *g = col.green / (double)65535;
      *b = col.blue / (double)65535;
    }
    
    private void set_mask (bool mask_for_composited = false)
    {
      var bitmap = new Gdk.Pixmap (null, UI_WIDTH, UI_HEIGHT+UI_LIST_HEIGHT, 1);
      var ctx = Gdk.cairo_create (bitmap);
      ctx.set_operator (Cairo.Operator.CLEAR);
      ctx.paint ();
      ctx.set_operator (Cairo.Operator.OVER);
      get_shape (ctx, mask_for_composited);
      if (window.is_composited() && !mask_for_composited)
      {
        window.input_shape_combine_mask (null, 0, 0);
        window.input_shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
      }
      else
      {
        window.shape_combine_mask (null, 0, 0);
        window.shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
      }
    }
    
    private void _cairo_path_for_main (Cairo.Context ctx, bool composited)
    {
      double w = UI_WIDTH, h = UI_HEIGHT;
      if (top_vbox != null)
      {
        w = top_vbox.allocation.width;
        h = top_vbox.allocation.height;
      }
      
      double PAD = 1;
      if (composited)
        rounded_rect (ctx, PAD, TOP_SPACING + PAD, w - PAD * 2, h - TOP_SPACING - PAD * 2, BORDER_RADIUS);
      else
      {
        /*
         __               y1
        |  |_______________ y2
        |                  |
        |__________________|y3
        x1 x3            x4
        */
        double x1 = PAD,
               x3 = PADDING * 2 + ICON_SIZE - PAD,
               x4 = w - PAD,
               y1 = PAD,
               y2 = PAD + TOP_SPACING,
               y3 = h - PAD,
               r = BORDER_RADIUS;
        ctx.move_to (x1, y3 - r);
        ctx.arc (x1+r, y1+r, r, Math.PI, Math.PI * 1.5);
        ctx.arc (x3-r, y1+r, r, Math.PI * 1.5, Math.PI * 2.0);
        ctx.line_to (x3, y2);
        ctx.arc (x4-r, y2+r, r, Math.PI * 1.5, Math.PI * 2.0);
        ctx.arc (x4-r, y3-r, r, 0, Math.PI * 0.5);
        ctx.arc (x1+r, y3-r, r, Math.PI * 0.5, Math.PI);
      }
    }
    
    private bool on_expose (Widget widget, Gdk.EventExpose event) {
        var ctx = Gdk.cairo_create (widget.window);
        /* Clear Stage */
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.set_operator (Cairo.Operator.OVER);

        /* Prepare bg's colors using GtkStyle */
        Gtk.Style style = widget.get_style();
        double r = 0.0, g = 0.0, b = 0.0;
        Pattern pat = new Pattern.linear(0, TOP_SPACING, 0, UI_HEIGHT);
        color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
        pat.add_color_stop_rgba (0, double.min(r + 0.15, 1),
                                    double.min(g + 0.15, 1),
                                    double.min(b + 0.15, 1),
                                    0.95);
        pat.add_color_stop_rgba (1, double.max(r - 0.15, 0),
                                    double.max(g - 0.15, 0),
                                    double.max(b - 0.15, 0),
                                    0.95);
        /* Prepare and draw top bg's rect */
        _cairo_path_for_main (ctx, widget.is_composited());
        ctx.set_source (pat);
        ctx.fill ();
        /* Add border */
        _cairo_path_for_main (ctx, widget.is_composited());
        ctx.set_line_width (2);
        ctx.set_source_rgba (1-r, 1-g, 1-b, 0.8);
        ctx.stroke ();
        
        if (list_visible && widget.is_composited())
        {
          double w = UI_WIDTH, h = UI_HEIGHT;
          if (top_vbox != null)
          {
            w = top_vbox.allocation.width;
            h = top_vbox.allocation.height;
          }
          ctx.rectangle ((w - UI_LIST_WIDTH) / 2 + 1, h, UI_LIST_WIDTH - 2, UI_LIST_HEIGHT);
          ctx.set_line_width (2.5);
          ctx.set_source_rgba (1-r, 1-g, 1-b, 0.8);
          ctx.stroke ();
        }
        
        if (searching_for_matches)
          cairofocus_search_match (ctx, widget);
        else
          cairofocus_search_action (ctx, widget);
        
        /* Propagate Expose */               
        Bin c = (widget is Bin) ? (Bin) widget : null;
        if (c != null)
          c.propagate_expose (c.get_child(), event);
        
        return true;
    }
    
    private void cairofocus_search_match (Cairo.Context ctx, Widget widget)
    {
      /*
         __               y1
        |  |_______________ y2
        |                  |
        |__________________|y3
        x1 x3            x4
        */
        double x1 = gco_main.allocation.x,
               x3 = main_label.allocation.x,
               x4 = main_label.allocation.x + main_label.allocation.width,
               y1 = gco_main.allocation.y,
               y2 = main_label.allocation.y,
               y3 = gco_main.allocation.y + gco_main.allocation.height,
               r = BORDER_RADIUS;
      ctx.new_path ();
      ctx.move_to (x1, y3 - r);
      ctx.arc (x1+r, y1+r, r, Math.PI, Math.PI * 1.5);
      ctx.arc (x3-r, y1+r, r, Math.PI * 1.5, Math.PI * 2.0);
      ctx.arc_negative (x3+r, y2-r*2, r, Math.PI, Math.PI * 0.5);
      ctx.arc (x4-r, y2, r, Math.PI * 1.5, Math.PI * 2.0);
      ctx.arc (x4-r, y3-r, r, 0, Math.PI * 0.5);
      ctx.arc (x1+r, y3-r, r, Math.PI * 0.5, Math.PI);
      
      Gtk.Style style = widget.get_style();
      double red = 0.0, green = 0.0, blue = 0.0;
      ctx.set_operator (Cairo.Operator.OVER);
      color_to_rgb (style.bg[Gtk.StateType.SELECTED], &red, &green, &blue);
      var pat = new Pattern.linear(0, y1, 0, y3);
      pat.add_color_stop_rgba (0.7, red,
                                  green,
                                  blue,
                                  0.0);
      pat.add_color_stop_rgba (1, red,
                                  green,
                                  blue,
                                  0.95);
      ctx.set_source (pat);
      ctx.clip ();
      ctx.paint ();
    }
    
    private void cairofocus_search_action (Cairo.Context ctx, Widget widget)
    {
      /*
         __________________ y1 
        |______________    |y2
                       |___|y3
        x1             x3  x4
        */
        double x1 = action_label.allocation.x,
               x3 = action_image.allocation.x,
               x4 = action_image.allocation.x + action_image.allocation.width,
               y1 = action_label.allocation.y,
               y2 = action_label.allocation.y + action_label.allocation.height,
               y3 = action_image.allocation.y + action_image.allocation.height,
               r = BORDER_RADIUS;
      ctx.new_path ();
      ctx.move_to (x1, y2 - r);
      ctx.arc (x1+r, y1+r, r, Math.PI, Math.PI * 1.5);
      ctx.arc (x4-r, y1 + r, r, Math.PI * 1.5, Math.PI * 2.0);
      ctx.arc (x4-r, y3-r, r, 0, Math.PI * 0.5);
      ctx.arc (x3+r, y3-r, r, Math.PI * 0.5, Math.PI);
      ctx.arc_negative (x3-r, y2+r, r, Math.PI * 2.0, Math.PI * 1.5);
      ctx.arc (x1+r, y2-r, r, Math.PI * 0.5, Math.PI);
      
      Gtk.Style style = widget.get_style();
      double red = 0.0, green = 0.0, blue = 0.0;
      ctx.set_operator (Cairo.Operator.OVER);
      color_to_rgb (style.bg[Gtk.StateType.SELECTED], &red, &green, &blue);
      var pat = new Pattern.linear(0, y3, 0, y1);
      pat.add_color_stop_rgba (0.0, red,
                                  green,
                                  blue,
                                  0.0);
      pat.add_color_stop_rgba (1, red,
                                  green,
                                  blue,
                                  0.95);
      ctx.set_source (pat);
      ctx.clip ();
      ctx.paint ();
    }
    
    /* UI shared components */
    private Image main_image = null;
    private Image main_image_overlay = null;
    private Label main_label = null;
    private Label pattern_label = null;
    private Label main_label_description = null;
    private Image action_image = null;
    private Label action_label = null;
    private HSelectionContainer sts = null;
    private ResultBox result_box = null;
    private HBox list_hbox = null;
    private HBox top_hbox = null;
    private VBox top_vbox = null;
    private Gtk.ContainerOverlayed gco_main = null;
    
    private static void _hilight_label (Widget w, bool b)
    {
      Label l = (Label) w;
      if (b)
      {
        string s = l.get_text();
        l.set_markup (Markup.printf_escaped ("<span size=\"large\"><u><b>%s</b></u></span>", s));
        l.sensitive = true;
      }
      else
      {
        string s = l.get_text();
        l.set_markup (Markup.printf_escaped ("<span size=\"small\">%s</span>", s));
        l.sensitive = false;
      }
    }

    private void build_ui ()
    {
      /* Constructing Main Areas*/
      
      /* main_vbox: VBox, to separate Top Area from List Area */
      var main_vbox = new VBox (false, 0);
      /* top_hbox: HBox, to separate Top Area contents */
      top_vbox = new VBox (false, 0);
      top_hbox = new HBox (false, 0);
      top_hbox.border_width = PADDING / 4;
      top_vbox.border_width = PADDING * 3 / 4;
      /* list_hbox: HBox, to separate List Area contents*/
      list_hbox = new HBox (false, 0);
      
      window.add (main_vbox);
      top_vbox.pack_start (top_hbox);
      main_vbox.pack_start (top_vbox, false);
      main_vbox.pack_start (list_hbox);
      
      /* Constructing Top Area */
      
      /* Match Icon */
      gco_main = new Gtk.ContainerOverlayed();
      main_image_overlay = new Image();
      main_image_overlay.set_pixel_size (ICON_SIZE / 2);
      main_image = new Image ();
      main_image.set_size_request (ICON_SIZE, ICON_SIZE);
      main_image.set_pixel_size (ICON_SIZE);
      gco_main.main = main_image;
      gco_main.overlay = main_image_overlay;
      top_hbox.pack_start (gco_main, false);
      
      /* VBox to push down the right area */
      var top_right_vbox = new VBox (false, 0);
      top_hbox.pack_start (top_right_vbox);
      /* Spacer */
      var spacer = new Label("");
      spacer.set_size_request (10, TOP_SPACING - PADDING + 10);
      /* STS */
      sts = new HSelectionContainer(_hilight_label, 15);
      //sts.set_selection_align (HSelectionContainer.SelectionAlign.LEFT);
      foreach (string s in this.categories)
        sts.add (new Label(s));
      /* HBox for the right area */
      var right_hbox = new HBox (false, 0);
      top_right_vbox.pack_start (spacer, false);
      top_right_vbox.pack_start (sts, false);
      top_right_vbox.pack_start (right_hbox);
      
      /* Constructing Top-Right Area */
      var labels_vbox = new VBox (false, 0);
      right_hbox.pack_start (labels_vbox);
      
      /* Match Title and Description */
      main_label_description = new Label ("");
      main_label_description.set_alignment (0, 0);
      main_label_description.set_ellipsize (Pango.EllipsizeMode.END); 
      main_label_description.set_line_wrap (true);
      main_label_description.xpad = PADDING;
      top_vbox.pack_start (main_label_description, false);
      
      main_label = new Label (null);
      main_label.set_alignment (0, 0);
      main_label.set_ellipsize (Pango.EllipsizeMode.END);

      pattern_label = new Label (null);
      pattern_label.set_alignment (0, 1.0f);
      pattern_label.set_ellipsize (Pango.EllipsizeMode.END);
      action_label = new Label (null);
      action_label.set_alignment (1.0f, 0.5f);
      var hbox_pattern_action = new HBox(false, 0);
      hbox_pattern_action.pack_start (pattern_label);
      hbox_pattern_action.pack_start (action_label);
      
      labels_vbox.pack_end (main_label, false, false, 10);
      labels_vbox.pack_start (hbox_pattern_action);
      
      /* Action Area */
      action_image = new Image ();
      action_image.set_pixel_size (ACTION_ICON_SIZE);
      action_image.set_size_request (ACTION_ICON_SIZE, ACTION_ICON_SIZE);
      right_hbox.pack_start (action_image, false, false, 10);
      
      /* ResultBox */
      result_box = new ResultBox(UI_LIST_WIDTH);
      var spacerleft = new Label("");
      var spacerright = new Label("");
      spacerright.set_size_request ((UI_WIDTH-UI_LIST_WIDTH) / 2 + 2, 10);
      spacerleft.set_size_request ((UI_WIDTH-UI_LIST_WIDTH) / 2 + 2, 10);
      list_hbox.pack_start (spacerleft,false);
      list_hbox.pack_start (result_box);
      list_hbox.pack_start (spacerright,false);
      list_hbox.name = "list_hbox";

      window.show_all();
    }
    
    bool searching_for_matches = true;
    
    /* EVENTS HANDLING HERE */
    private void search_add_char (string chr)
    {
      if (searching_for_matches)
        set_match_search (get_match_search() + chr);
      else
        set_action_search (get_action_search() + chr);
    }
    private void search_delete_char ()
    {
      string s = "";
      if (searching_for_matches)
        s = get_match_search ();
      else
        s = get_action_search ();
      long len = s.length;
      if (len > 0)
      {
        s = s.substring (0, len - 1);
        if (searching_for_matches)
          set_match_search (s);
        else
          set_action_search (s);
      }
    }
    
    private void hide_and_reset ()
    {
      window.hide ();
      set_list_visible (false);
      sts.select (0);
      reset_search ();
    }
    
    public void present_with_time (uint32 timestamp)
    {
      window.present_with_time (timestamp);
    }
    
    protected bool key_press_event (Gdk.EventKey event)
    {
      if (im_context.filter_keypress (event)) return true;

      uint key = event.keyval;
      switch (key)
      {
        case Gdk.KeySyms.Return:
        case Gdk.KeySyms.KP_Enter:
        case Gdk.KeySyms.ISO_Enter:
          debug ("enter pressed");
          
          break;
        case Gdk.KeySyms.Delete:
        case Gdk.KeySyms.BackSpace:
          search_delete_char ();
          break;
        case Gdk.KeySyms.Escape:
          debug ("escape");
          if (!searching_for_matches)
          {
            set_action_search ("");
            searching_for_matches = true;
          }
          else if (get_match_search() != "")
          {
            set_match_search("");
            set_list_visible (false);
          }
          else
          {
            hide_and_reset ();
          }
          break;
        case Gdk.KeySyms.Left:
          sts.select_prev ();
          update_query_flags (this.categories_query[sts.get_selected()]);
          break;
        case Gdk.KeySyms.Right:
          sts.select_next ();
          update_query_flags (this.categories_query[sts.get_selected()]);
          break;
        case Gdk.KeySyms.Up:
          bool b = true;
          if (searching_for_matches)
            b = select_prev_match ();
          else
            b = select_prev_action ();
          if (!b)
            set_list_visible (false);
          break;
        case Gdk.KeySyms.Down:
          if (searching_for_matches)
            select_next_match ();
          else
            select_next_action ();
          set_list_visible (true);
          break;
        case Gdk.KeySyms.Tab:
          if (searching_for_matches && 
              (get_match_results () == null || get_match_results ().size == 0))
            return true;
          searching_for_matches = !searching_for_matches;
          Match m = null;
          int i = 0;
          if (searching_for_matches)
          {
            get_match_focus (out i, out m);
            update_match_result_list (get_match_results (), i, m);
            get_action_focus (out i, out m);
            focus_action (i, m);
          }
          else
          {
            get_action_focus (out i, out m);
            update_action_result_list (get_action_results (), i, m);
            get_match_focus (out i, out m);
            focus_match (i, m);
          }
          window.queue_draw ();
          break;
        default:
          debug ("im_context didn't filter...");
          break;
      }

      return true;
    }
    private void set_list_visible (bool b)
    {
      if (b==this.list_visible)
        return;
      this.list_visible = b;
      if (b)
        list_hbox.show();
      else
        list_hbox.hide();
      set_mask ();
    }   
    
    private void show_pattern (string pat)
    {
      pattern_label.set_markup (Markup.printf_escaped ("<span size=\"medium\">%s</span>", pat));
    }

    private string markup_string_with_search (string text, string pattern, string size = "xx-large")
    {
      if (pattern == "")
      {
        return Markup.printf_escaped ("<span size=\"%s\">%s</span>", size, text);
      }
      // if no text found, use pattern
      if (text == "")
      {
        show_pattern (pattern);
        return Markup.printf_escaped ("<span size=\"%s\"><b><u> </u></b></span>", size);
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
      }
      if (highlighted != null)
      {
        show_pattern ("");
        return "<span size=\"%s\">%s</span>".printf (size,highlighted);
      }
      else
      {
        show_pattern (pattern);
        return Markup.printf_escaped ("<span size=\"%s\">%s</span>", size, text);
      }
    }

    private string get_description_markup (string s)
    {
      return Markup.printf_escaped ("<span size=\"medium\">%s</span>", s);
    }
    
    public void show_sezen ()
    {
      window.show_all ();
      set_list_visible (false);
    }
    
    /* UI INTERFACE IMPLEMENTATION */
    protected override void focus_match ( int index, Match? match )
    {
      string size = searching_for_matches ? "xx-large": "medium";
      if (match == null)
      {
        /* Show default stuff */
        if (get_match_search () != "")
        {
          main_label.set_markup (markup_string_with_search ("", get_match_search (), size));
          main_label_description.set_markup (get_description_markup ("Match not found."));
          main_image.set_from_icon_name ("search", IconSize.DIALOG);
          main_image_overlay.clear ();
        }
        else
        {
          main_image.set_from_icon_name ("search", IconSize.DIALOG);
          main_image_overlay.clear ();
          main_label.set_markup (
            Markup.printf_escaped ("<span size=\"xx-large\">%s</span>",
                                   "Type to search..."));
          main_label_description.set_markup (
            Markup.printf_escaped ("<span size=\"medium\"> </span>" +
                                   "<span size=\"smaller\">%s</span>",
                                   "Powered by Zeitgeist"));
          show_pattern ("");
        }
      }
      else
      {
        try
        {
          main_image.set_from_gicon (GLib.Icon.new_for_string (match.icon_name), IconSize.DIALOG);
          if (match.has_thumbnail)
            main_image_overlay.set_from_gicon (GLib.Icon.new_for_string (match.thumbnail_path), IconSize.DIALOG);
          else
            main_image_overlay.clear ();
        }
        catch (Error err)
        {
          main_image.set_from_icon_name ("missing-image", IconSize.DIALOG);
          main_image_overlay.clear ();
        }
        main_label.set_markup (markup_string_with_search (match.title, get_match_search (), size));
        main_label_description.set_markup (get_description_markup (match.description));
        result_box.move_selection_to_index (index);
      }
    }
    protected override void focus_action ( int index, Match? action )
    {
      string size = !searching_for_matches ? "xx-large": "medium";
      if (action == null)
      {
        action_image.set_sensitive (false);
        action_image.set_from_icon_name ("system-run", IconSize.DIALOG);
        action_label.set_markup (markup_string_with_search ("", "", size));
      }
      else
      {
        action_image.set_sensitive (true);
        try
        {
          action_image.set_from_gicon (GLib.Icon.new_for_string (action.icon_name), IconSize.DIALOG);
        }
        catch (Error err)
        {
          action_image.set_from_icon_name ("missing-image", IconSize.DIALOG);
        }
        action_label.set_markup (markup_string_with_search (action.title,
                                 searching_for_matches ? 
                                 "" : get_action_search (), size));
        if (!searching_for_matches)
        {
          result_box.move_selection_to_index (index);
        }
      }
    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {
      if (searching_for_matches)
      {
        result_box.update_matches (matches);
        if (matches == null || matches.size == 0)
          set_list_visible (false);
      }
      focus_match ( index, match );
    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {
      if (!searching_for_matches)
      {
        result_box.update_matches (actions);
        if (actions == null || actions.size == 0)
          set_list_visible (false);
      }
      focus_action (index, action);
    }
    
    public static int main (string[] argv)
    {
      Gtk.init (ref argv);
      var window = new SezenWindow ();

      var registry = GtkHotkey.Registry.get_default ();
      GtkHotkey.Info hotkey;
      try
      {
        if (registry.has_hotkey ("sezen2", "activate"))
        {
          hotkey = registry.get_hotkey ("sezen2", "activate");
        }
        else
        {
          hotkey = new GtkHotkey.Info ("sezen2", "activate",
                                       "<Control>space", null);
          registry.store_hotkey (hotkey);
        }
        debug ("Binding activation to %s", hotkey.signature);
        hotkey.bind ();
        hotkey.activated.connect ((event_time) =>
        {
          window.show_sezen();
          window.present_with_time (event_time);
        });
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }

      Gtk.main ();
      return 0;
    }
  }
  
  /* Support Classes */
  public class SezenTypeSelector: Label
  {
    private string[] types;
    private int[] lens;
    private int selected = 0;

    public SezenTypeSelector (string[] types_array)
    {
      this.types = types_array;
      this.lens.resize (types.length);
      this.set_markup ("");
      this.set_alignment (0, 0);
      this.set_ellipsize (Pango.EllipsizeMode.END);
      this.set_selected (0);
    }
    
    public void select_next ()
    {
      set_selected (selected + 1);
    }
    
    public void select_prev ()
    {
      set_selected (selected - 1);
    }
    
    public int get_selected ()
    {
      return selected;
    }
    
    public void set_selected (int sel)
    {
      if (sel < 0)
        sel = types.length - 1;
      else if (sel >= types.length)
        sel = 0;

      string s = Markup.printf_escaped ("<span size=\"large\">Search Type: &gt; <b>%s</b> &lt;</span>", types[sel]);

      this.selected = sel;
      this.set_markup (s);
      this.queue_draw ();
    }
  }
  /* Result List stuff */
  public class ResultBox: EventBox
  {
    private const int VISIBLE_RESULTS = 5;
    private const int ICON_SIZE = 35;
    private int mwidth;
    private bool no_results;
    
    public ResultBox (int width)
    {
      this.mwidth = width;
      no_results = true;
      build_ui();
    }
    
    private enum Column {
			IconColumn = 0,
			NameColumn = 1,
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
        SezenWindow.color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
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
      var vbox = new VBox (false, 0);
      this.expose_event.connect (on_expose);
      vbox.border_width = 1;
      this.add (vbox);
      var resultsScrolledWindow = new ScrolledWindow (null, null);
      resultsScrolledWindow.set_policy (PolicyType.NEVER, PolicyType.NEVER);
      vbox.pack_start (resultsScrolledWindow);
      var tb = new HBox (false, 0);
      tb.set_size_request (mwidth, 15);
      vbox.pack_start (tb, false);
      status = new Label ("");
      status.set_alignment (0, 0);
      status.set_markup (Markup.printf_escaped ("<b>%s</b>", "No results."));
      var logo = new Label ("");
      logo.set_alignment (1, 0);
      logo.set_markup (Markup.printf_escaped ("<i>Sezen 2 </i>"));
      tb.pack_start (status, true, true, 10);
      tb.pack_start (logo, false, false, 10);
      
      view = new TreeView ();
			view.enable_search = false;
			view.headers_visible = false;
			// If this is not set the tree will call IconDataFunc for all rows to 
			// determine the total height of the tree
			view.fixed_height_mode = true;
			resultsScrolledWindow.add (view);
			view.show();
      // Model
      view.model = results = new ListStore(2, typeof(GLib.Icon), typeof(string));

      var column = new TreeViewColumn ();
			column.sizing = Gtk.TreeViewColumnSizing.FIXED;

			var crp = new CellRendererPixbuf ();
      crp.set_fixed_size (ICON_SIZE, ICON_SIZE);
      crp.stock_size = IconSize.DND;
			column.pack_start (crp, false);
			column.add_attribute (crp, "gicon", (int) Column.IconColumn);
			
			var ctxt = new CellRendererText ();
			ctxt.ellipsize = Pango.EllipsizeMode.END;
			ctxt.set_fixed_size (mwidth - ICON_SIZE, ICON_SIZE);
			column.pack_start (ctxt, false);
      column.add_attribute (ctxt, "markup", (int) Column.NameColumn);
      
      view.append_column (column);
    }    
    public void update_matches (Gee.List<Sezen.Match>? rs)
    {
      results.clear();
      if (rs==null)
      {
        no_results = true;
        status.set_markup (Markup.printf_escaped ("<b>%s</b>", "No results."));
        return;
      }
      no_results = false;
      TreeIter iter;
      foreach (Match m in rs)
      {
        results.append (out iter);
        results.set (iter, Column.IconColumn, GLib.Icon.new_for_string(m.icon_name), Column.NameColumn, 
                     Markup.printf_escaped ("<span><b>%s</b></span>\n<span size=\"small\">%s</span>",m.title, m.description));
      }
      var sel = view.get_selection ();
      sel.select_path (new TreePath.first());
      status.set_markup (Markup.printf_escaped ("<b>1 of %d</b>", results.length));
    }
    public void move_selection_to_index (int i)
    {
      var sel = view.get_selection ();
      Gtk.TreePath path = new TreePath.from_string( i.to_string() );
      /* Scroll to path */
      Timeout.add(1, () => {
          sel.unselect_all ();
          sel.select_path (path);
          view.scroll_to_cell (path, null, true, 0.5F, 0.0F);
          return false;
      });
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
      status.set_markup (Markup.printf_escaped ("<b>%d of %d</b>", index + 1, results.length));
      return index;
    }
  }
}

namespace Gtk
{
  public class ContainerOverlayed: Gtk.Container
  {
    public float scale {get; set; default = 0.25f;}
    private Widget _main = null;
    private Widget _overlay = null;
    public Widget main { get {return _main;}
                         set {
                               if(_main!=null)
                               {
                                 _main.unparent();
                                 _main = null;
                               }
                               if(value!=null)
                               {
                                 _main = value;
                                 _main.set_parent(this);
                               }
                             }
                       }
    public Widget overlay  { get {return _overlay;}
                             set {
                                   if(_overlay!=null)
                                   {
                                     _overlay.unparent();
                                     _overlay = null;
                                   }
                                   if(value!=null)
                                   {
                                     _overlay = value;
                                     _overlay.set_parent(this);
                                   }
                                 }
                           }
    public ContainerOverlayed ()
    {
      set_has_window(false);
      set_redraw_on_allocate(false);
    }
    public override void size_request (out Requisition requisition)
    {
      Requisition req = {0, 0};
      requisition.width = 1;
      requisition.height = 1;
      if (main != null)
      {
        main.size_request (out req);
        requisition.width = int.max(req.width, requisition.width);
        requisition.height = int.max(req.height, requisition.height);
      }
      if (overlay != null)
      {
        overlay.size_request (out req);
        requisition.width = int.max(req.width, requisition.width);
        requisition.height = int.max(req.height, requisition.height);
      }
    }
    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Gdk.Rectangle aoverlay = {allocation.x,
                                allocation.y + allocation.height / 2,
                                allocation.width / 2,
                                allocation.height / 2
                                };
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);    
      main.size_allocate (allocation);
      overlay.size_allocate (aoverlay);
    }
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      if (main != null)
        callback (main);
      if (overlay != null)
        callback (overlay);
    }

    public override void add (Widget widget)
    {
      if (main == null)
      {
        main = widget;
      }
      else if (overlay == null)
      {
        overlay = widget;
      }
    }
    public override void remove (Widget widget)
    {
      if (overlay == widget)
      {
        widget.unparent ();
        overlay = null;
        return;
      }
      if (main == widget)
      {
        widget.unparent ();
        main = null;
      }
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
    }

    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);
      int lastx = 0;
      Requisition req = {0, 0};
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
          offset = allocation.width - allocations[selection];
          childs.get (selection).size_request (out req);
          offset -= req.width;
          break;
        default:
          offset = allocation.width / 2 - allocations[selection];
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
        if (pos < 0 || pos + req.width > alloc.width)
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
          allocation.y = alloc.y + (alloc.height - req.height) / 2;
          w.size_allocate (allocation);
          w.show_all ();
        }
        ++i;
      }
    }
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      int i = 0;
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
}
