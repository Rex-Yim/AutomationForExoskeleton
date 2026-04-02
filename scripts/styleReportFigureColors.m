function styleReportFigureColors(fig)
%% styleReportFigureColors — force axes/titles/ticks/labels/legends to black for PDF reports.
% Call after building a figure (subplots, pipelines, etc.).

    if nargin < 1 || ~isgraphics(fig)
        return
    end
    blk = [0 0 0];
    axs = findall(fig, 'Type', 'axes');
    for i = 1:numel(axs)
        ax = axs(i);
        try
            ax.XColor = blk;
            ax.YColor = blk;
            if isprop(ax, 'ZColor')
                ax.ZColor = blk;
            end
            if isgraphics(ax.Title)
                ax.Title.Color = blk;
            end
            if isgraphics(ax.XLabel)
                ax.XLabel.Color = blk;
            end
            if isgraphics(ax.YLabel)
                ax.YLabel.Color = blk;
            end
            if isprop(ax, 'TickLabelColor')
                ax.TickLabelColor = blk;
            end
        catch
        end
    end
    legs = findall(fig, 'Type', 'legend');
    for i = 1:numel(legs)
        try
            lg = legs(i);
            if isprop(lg, 'TextColor')
                lg.TextColor = blk;
            end
            if isprop(lg, 'Color')
                lg.Color = 'w';
            end
        catch
        end
    end
    cbs = findall(fig, 'Type', 'colorbar');
    for i = 1:numel(cbs)
        try
            cb = cbs(i);
            if isprop(cb, 'Color')
                cb.Color = blk;
            end
            if isprop(cb, 'FontColor')
                cb.FontColor = blk;
            end
            if isgraphics(cb.Label)
                cb.Label.Color = blk;
            end
        catch
        end
    end
end
