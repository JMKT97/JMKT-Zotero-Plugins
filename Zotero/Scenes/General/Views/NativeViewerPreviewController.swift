//
//  NativeViewerPreviewController.swift
//  Zotero
//

import QuickLook
import UIKit

import RxSwift

final class NativeViewerPreviewController: QLPreviewController {
    private let previewItem: QLPreviewItem
    private let disposeBag: DisposeBag

    init(url: URL, title: String?) {
        self.previewItem = NativeViewerPreviewItem(url: url, title: title)
        self.disposeBag = DisposeBag()
        super.init(nibName: nil, bundle: nil)
        self.dataSource = self
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        let closeItem = UIBarButtonItem(title: L10n.close, style: .plain, target: nil, action: nil)
        closeItem.rx
                 .tap
                 .observe(on: MainScheduler.instance)
                 .subscribe(onNext: { [weak self] in
                     self?.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
                 })
                 .disposed(by: disposeBag)
        navigationItem.leftBarButtonItem = closeItem
    }
}

extension NativeViewerPreviewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewItem
    }
}

private final class NativeViewerPreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(url: URL, title: String?) {
        self.previewItemURL = url
        self.previewItemTitle = title
    }
}
