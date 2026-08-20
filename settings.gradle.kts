rootProject.name = "coffeevision"
enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

pluginManagement {
    includeBuild("build-logic")
    repositories {
        google {
            mavenContent {
                includeGroupAndSubgroups("androidx")
                includeGroupAndSubgroups("com.android")
                includeGroupAndSubgroups("com.google")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google {
            mavenContent {
                includeGroupAndSubgroups("androidx")
                includeGroupAndSubgroups("com.android")
                includeGroupAndSubgroups("com.google")
            }
        }
        mavenCentral()
    }
}

include(":androidApp")
include(":sharedUI")
include(":shared:core")
include(":shared:domain")
include(":shared:data-local")
include(":shared:data-firebase")
include(":shared:data-places")
include(":shared:feature:coffee-list")
include(":shared:feature:coffee-detail")
include(":shared:feature:coffee-editor")
include(":shared:feature:cafe-search")
include(":shared:feature:map")
include(":shared:feature:cafe-detail")
include(":shared:feature:account")
include(":shared:feature:analysis")
include(":shared:framework")