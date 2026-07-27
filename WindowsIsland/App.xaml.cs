using System.Windows;
using System.Windows.Controls;
using System.Linq;
using System.Windows.Threading;
using CodexUIsland.Services;

namespace CodexUIsland;

public partial class App : Application
{
    private NotificationListener? _listener;
    private IslandWindow? _island;
    private DispatcherTimer? _snapshotTimer;
    private bool _enabled = true;

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Create the overlay pill window (invisible until a notification arrives)
        _island = new IslandWindow();
        _island.Show();
        ShowLocalSnapshot();

        _snapshotTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
        _snapshotTimer.Tick += (_, _) => ShowLocalSnapshot();
        _snapshotTimer.Start();

        if (!e.Args.Contains("--notifications")) return;

        // Create services
        var suppressor = new ToastSuppressor();
        _listener = new NotificationListener(suppressor);

        // Wire notification events to the UI
        _listener.OnNotificationReceived += data =>
        {
            _island.Dispatcher.Invoke(() => _island.ShowNotification(data));
        };

        await _listener.StartAsync();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _snapshotTimer?.Stop();
        _listener?.Stop();
        var tray = (Hardcodet.Wpf.TaskbarNotification.TaskbarIcon?)Current.Resources["TrayIcon"];
        tray?.Dispose();
        base.OnExit(e);
    }

    private void ShowLocalSnapshot()
    {
        var snapshot = CodexUSnapshotReader.Load();
        _island?.ShowSnapshot(snapshot);
    }

    private void Toggle_Click(object sender, RoutedEventArgs e)
    {
        _enabled = !_enabled;
        if (_listener != null) _listener.Enabled = _enabled;
        var item = sender as MenuItem;
        if (item != null)
            item.Header = _enabled ? "Disable notifications" : "Enable notifications";
    }

    private void Quit_Click(object sender, RoutedEventArgs e)
    {
        Current.Shutdown();
    }
}
