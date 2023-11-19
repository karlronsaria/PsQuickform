. "$PsScriptRoot\..\Controls.ps1"

[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

$main = New-ControlsMain

$listBox = New-Control ListBox
$listBox.SelectionMode = 'Multiple'
$listBox.Height = 50
$listBox.Width = 200
$main.Grid.AddChild($listBox)

$button = New-Control Button
$button.Width = 50
$button.Content = '+'
$main.Grid.AddChild($button)

$closure =
    New-Closure `
        -InputObject $listBox `
        -ScriptBlock {
            $InputObject.Items.Add("")
        }

$button.add_Click($closure)

$main.Window.ShowDialog()




<#
## 2023_11_17_234110
[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    >
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition
                MinHeight="400"
                Height="*"
                />
            <RowDefinition Height="50"/>
            <RowDefinition Height="50"/>
        </Grid.RowDefinitions>

        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="2*"/>
            <ColumnDefinition Width="5*"/>
        </Grid.ColumnDefinitions>

        <!-- todo: lookup: wpf ListView CanReorderItems -->
        <ListView
            Name="listView"
            Grid.Row="0"
            Grid.Column="0"
            Margin="5"
            AllowDrop="True"
            ScrollViewer.VerticalScrollBarVisibility="Auto"
            >

            <ListView.ItemTemplate>
                <DataTemplate>
                    <StackPanel
                        MinWidth="150"
                        >
                        <TextBox
                            Text="{Binding Name}"
                            IsReadOnly="True"
                            BorderThickness="0"
                            />
                        <TextBox
                            Text="{Binding Description}"
                            IsReadOnly="True"
                            BorderThickness="0"
                            />
                    </StackPanel>
                </DataTemplate>
            </ListView.ItemTemplate>
        </ListView>

        <Grid
            Name="gridViewContainer"
            Grid.Row="0"
            Grid.Column="1"
            Grid.ColumnSpan="1"
            Margin="5"
            >
            <ListView
                Name="gridView"
                >

                <ListView.ItemsPanel>
                    <ItemsPanelTemplate>
                        <WrapPanel
                            MaxWidth="{
                                Binding ActualWidth,
                                ElementName=gridViewContainer
                            }"
                            HorizontalAlignment="Left"
                            />
                    </ItemsPanelTemplate>
                </ListView.ItemsPanel>

                <ListView.ItemTemplate>
                    <DataTemplate>
                        <StackPanel
                            MinWidth="200"
                            >
                            <TextBox
                                Text="{Binding Name}"
                                IsReadOnly="True"
                                IsEnabled="False"
                                BorderThickness="0"
                                />
                            <TextBox
                                Text="{Binding Description}"
                                IsReadOnly="True"
                                IsEnabled="False"
                                BorderThickness="0"
                                />
                        </StackPanel>
                    </DataTemplate>
                </ListView.ItemTemplate>

            </ListView>
        </Grid>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$form = $null

try {
    $form = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    Write-Output "Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing, PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered."
    return
}

$ui = [PsCustomObject]@{}

$xaml.SelectNodes("//*[@Name]") | foreach {
    $ui | Add-Member `
        -MemberType 'NoteProperty' `
        -Name $_.Name `
        -Value $form.FindName($_.Name)
}

$ui.listView.add_Drop({
    Write-Host $_.Data.GetData([System.Windows.DataFormats]::StringFormat)
})

$ui.gridView.add_SelectionChanged({
    $item = $this.SelectedItem

    if ($null -eq $item) {
        return
    }

    $this.FindName('listView').Items.Add($item)
})

[void] $ui.listView.Items.Add([PsCustomObject]@{
    Name = 'Sus'
    Description = "A sus."
})

[void] $ui.listView.Items.Add([PsCustomObject]@{
    Name = 'Ihr'
    Description = "An ihr."
})

[void] $ui.listView.Items.Add([PsCustomObject]@{
    Name = 'Oth'
    Description = "An oth."
})

$itemId = 0

1 .. 15 | foreach {
    [void] $ui.gridView.Items.Add([PsCustomObject]@{
        Id = $itemId++
        Name = 'Sus'
        Description = "A sus."
    })

    [void] $ui.gridView.Items.Add([PsCustomObject]@{
        Id = $itemId++
        Name = 'Ihr'
        Description = "An ihr."
    })

    [void] $ui.gridView.Items.Add([PsCustomObject]@{
        Id = $itemId++
        Name = 'Oth'
        Description = "An oth."
    })
}

$form.ShowDialog()
#>





