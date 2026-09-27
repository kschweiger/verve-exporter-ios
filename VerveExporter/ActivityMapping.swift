import HealthKit

struct VerveActivityCategory {
    let type: String
    let subType: String?
}

enum VerveActivityMapper {
    private static let fixedCategories: [(HKWorkoutActivityType, VerveActivityCategory)] = [
        (.hiking, VerveActivityCategory(type: "Foot Sports", subType: "Hike")),
        (.crossCountrySkiing, VerveActivityCategory(type: "Winter Sports", subType: "Cross-country Skiing")),
        (.downhillSkiing, VerveActivityCategory(type: "Winter Sports", subType: "Downhill Skiing")),
        (.snowSports, VerveActivityCategory(type: "Winter Sports", subType: "Downhill Skiing")),
        (.snowboarding, VerveActivityCategory(type: "Winter Sports", subType: "Downhill Skiing")),
        (.traditionalStrengthTraining, VerveActivityCategory(type: "Strength Training", subType: "Weight Training")),
        (.functionalStrengthTraining, VerveActivityCategory(type: "Strength Training", subType: "Circuit Training")),
        (.crossTraining, VerveActivityCategory(type: "Strength Training", subType: "CrossFit")),
        (.elliptical, VerveActivityCategory(type: "Indoor Cardio", subType: "Elliptical")),
        (.stairClimbing, VerveActivityCategory(type: "Indoor Cardio", subType: "Stair Stepper")),
        (.rowing, VerveActivityCategory(type: "Indoor Cardio", subType: "Indoor Rowing")),
        (.yoga, VerveActivityCategory(type: "Fitness & Flexibility", subType: "Yoga")),
        (.pilates, VerveActivityCategory(type: "Fitness & Flexibility", subType: "Pilates")),
        (.highIntensityIntervalTraining, VerveActivityCategory(type: "Fitness & Flexibility", subType: "HIIT")),
        (.climbing, VerveActivityCategory(type: "Climbing", subType: nil)),
        (.skatingSports, VerveActivityCategory(type: "Other", subType: "Skateboarding"))
    ]

    static func category(
        for workout: HKWorkout,
        swimmingLocationType: HKWorkoutSwimmingLocationType?
    ) -> VerveActivityCategory {
        let isIndoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false

        switch workout.workoutActivityType {
        case .cycling:
            return VerveActivityCategory(type: "Cycling", subType: isIndoor ? "Indoor" : nil)
        case .walking, .running:
            let subType = workout.workoutActivityType == .walking ? "Walk" : "Run"
            return VerveActivityCategory(
                type: "Foot Sports",
                subType: isIndoor ? "Treadmill" : subType
            )
        case .swimming:
            return swimmingCategory(
                isIndoor: isIndoor,
                locationType: swimmingLocationType
            )
        default:
            return fixedCategories.first { $0.0 == workout.workoutActivityType }?.1
                ?? VerveActivityCategory(type: "Other", subType: "Other")
        }
    }

    private static func swimmingCategory(
        isIndoor: Bool,
        locationType: HKWorkoutSwimmingLocationType?
    ) -> VerveActivityCategory {
        switch locationType {
        case .pool:
            return VerveActivityCategory(type: "Swimming", subType: isIndoor ? "Indoor" : "Outdoor Pool")
        case .openWater:
            return VerveActivityCategory(type: "Swimming", subType: "Open Water")
        case .unknown, nil:
            return VerveActivityCategory(type: "Swimming", subType: isIndoor ? "Indoor" : "Open Water")
        @unknown default:
            return VerveActivityCategory(type: "Swimming", subType: isIndoor ? "Indoor" : "Open Water")
        }
    }
}

enum WorkoutActivityIconMapper {
    private static let icons: [(HKWorkoutActivityType, String)] = [
        (.running, "figure.run"),
        (.walking, "figure.walk"),
        (.hiking, "figure.hiking"),
        (.cycling, "figure.outdoor.cycle"),
        (.swimming, "figure.pool.swim"),
        (.elliptical, "figure.elliptical"),
        (.traditionalStrengthTraining, "dumbbell.fill"),
        (.functionalStrengthTraining, "dumbbell.fill"),
        (.yoga, "figure.yoga"),
        (.crossTraining, "figure.cross.training"),
        (.dance, "figure.dance"),
        (.rowing, "figure.rower"),
        (.coreTraining, "figure.core.training"),
        (.cooldown, "figure.cooldown"),
        (.climbing, "figure.climbing")
    ]

    static func systemName(for type: HKWorkoutActivityType) -> String {
        icons.first { $0.0 == type }?.1 ?? "figure.mixed.cardio"
    }
}
