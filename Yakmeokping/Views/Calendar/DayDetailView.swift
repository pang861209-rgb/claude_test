import SwiftUI

/// 특정 날짜의 상세: 슬롯별 완료 시각과 인증 사진 크게 보기.
struct DayDetailView: View {
    @Environment(MedicationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let day: Date

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text(titleString)
                        .font(Theme.rounded(22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 20)

                    ForEach(Slot.allCases) { slot in
                        slotSection(slot)
                    }
                }
                .padding(20)
            }
        }
    }

    private func slotSection(_ slot: Slot) -> some View {
        let record = store.record(for: slot, on: day)
        let completed = record?.status == .completed

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(slot.emoji)
                Text(slot.displayName)
                    .font(Theme.rounded(18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: completed ? "heart.fill" : "heart")
                    .foregroundStyle(completed ? Theme.mainPink : Theme.textSecondary.opacity(0.4))
            }

            if completed, let record {
                if let at = record.completedAt {
                    Text(record.isLate
                         ? "\(timeString(at)) 인증 · 조금 늦었지만 해냈어요 💜"
                         : "\(timeString(at)) 인증 완료 💗")
                        .font(Theme.rounded(14))
                        .foregroundStyle(record.isLate ? Theme.pointPurple : Theme.mainPink)
                }
                if let path = record.photoPath, let image = PhotoStorage.load(relativePath: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            } else {
                Text("이 회차는 기록이 없어요 🤍")
                    .font(Theme.rounded(14))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    private var titleString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: day)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: date)
    }
}
