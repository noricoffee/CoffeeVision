package com.noricoffee.coffeevision

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.noricoffee.VisitListScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        setContent {
            MaterialTheme {
                VisitListScreen(CoffeeVisionApp.appContainer)
            }
        }
    }
}

@Preview
@Composable
fun AppAndroidPreview() {
    // Preview では AppContainer を構築できないため、プレースホルダーテキストを表示する。
    // Phase 5 以降でダミー AppContainer を用意する場合に差し替える。
    androidx.compose.material3.Text("Preview Placeholder")
}